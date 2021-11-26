//
// UPnPControlPoint.swift
// 

import Foundation
import SwiftHttpServer

/**
 UPnP ControlPoint Delegate
 */
public protocol UPnPControlPointDelegate {
    /**
     On Device Added
     */
    func onDeviceAdded(device: UPnPDevice)
    /**
     On Device Removed
     */
    func onDeviceRemoved(device: UPnPDevice)
}

/**
 scpdHandler
 */
public typealias scpdHandler = ((UPnPDevice?, UPnPService?, UPnPScpd?, String?) -> Void)

/**
 UPnP Control Point Implementation
 */
public class UPnPControlPoint : UPnPDeviceBuilderDelegate, HttpRequestHandlerDelegate {

    /**
     http server bind hostname
     */
    public var hostname: String?
    /**
     http server bind port
     */
    public var port: Int
    /**
     http server
     */
    public var httpServer : HttpServer?
    /**
     ssdp receiver
     */
    public var ssdpReceiver : SSDPReceiver?
    /**
     devices
     */
    public var devices = [String:UPnPDevice]()
    /**
     delegate
     */
    var delegate: UPnPControlPointDelegate?
    /**
     event subscribers
     */
    var eventSubscribers = [UPnPEventSubscriber]()
    /**
     event property handlers
     */
    var eventNotificationHandlers = [eventNotificationHandler]()
    /**
     on device added handlers
     */
    var onDeviceAddedHandlers = [(UPnPDevice) -> Void]()
    /**
     on device removed handlers
     */
    var onDeviceRemovedHandlers = [(UPnPDevice) -> Void]()
    /**
     on scpd handlers
     */
    var onScpdHandlers = [scpdHandler]()

    /**
     timer
     */
    var timer: DispatchSourceTimer?
    
    public init(httpServerBindHostname: String? = nil, httpServerBindPort: Int = 0) {
        if httpServerBindHostname == nil {
            self.hostname = Network.getInetAddress()?.hostname
        } else {
            self.hostname = httpServerBindHostname
        }
        self.port = httpServerBindPort
    }

    deinit {
        finish()
    }

    /**
     Get Event Subscriber with sid (subscription id)
     */
    public func getEventSubscriber(sid: String) -> UPnPEventSubscriber? {
        for subscriber in eventSubscribers {
            guard let subscriber_sid = subscriber.sid else {
                continue
            }
            if subscriber_sid == sid {
                return subscriber
            }
        }
        return nil
    }

    /**
     Start UPnP Control Point
     */
    public func run() throws {
        startHttpServer()
        startSsdpReceiver()
        try startTimer()
    }

    /**
     Get device with UDN
     */
    public func getDevice(udn: String) -> UPnPDevice? {
        return devices[udn]
    }

    /**
     add event notification handler
     */
    public func addEventNotificationHandler(eventHandler: eventNotificationHandler?) {
        guard let handler = eventHandler else {
            return
        }
        eventNotificationHandlers.append(handler)
    }

    /**
     Start HTTP Server
     */
    public func startHttpServer() {
        
        DispatchQueue.global(qos: .default).async {

            guard self.httpServer == nil else {
                print("UPnPControlPoint::startHttpServer() already started")
                // already started
                return
            }

            do {
                self.httpServer = HttpServer(hostname: self.hostname, port: self.port)
                try self.httpServer!.route(pattern: "/notify/**", handler: self)

                try self.httpServer!.run()
            } catch let error{
                print("UPnPControlPoint::startHttpServer() error - error - \(error)")
            }
            self.httpServer = nil
        }
    }

    public func onHeaderCompleted(header: HttpHeader, request: HttpRequest, response: HttpResponse) throws {
    }

    public func onBodyCompleted(body: Data?, request: HttpRequest, response: HttpResponse) throws {
        print("UPnPControlPoint::startHttpServer() path -- \(request.path)")
        guard let sid = request.header["sid"] else {
            let err = HttpServerError.illegalArgument(string: "No SID")
            handleEventProperties(subscription: nil, properties: nil, error: err)
            throw err
        }

        guard let subscription = getEventSubscriber(sid: sid)?.subscription else {
            let err = HttpServerError.illegalArgument(string: "No Subscription Found with SID: '\(sid)'")
            handleEventProperties(subscription: nil, properties: nil, error: err)
            throw err
        }

        guard let data = body else {
            let err = HttpServerError.illegalArgument(string: "No Content")
            handleEventProperties(subscription: subscription, properties: nil, error: err)
            throw err
        }

        guard let xmlString = String(data: data, encoding: .utf8) else {
            let err = HttpServerError.illegalArgument(string: "Wrong XML String")
            handleEventProperties(subscription: subscription, properties: nil, error: err)
            throw err
        }

        guard let properties = UPnPEventProperties.read(xmlString: xmlString) else {
            let err = HttpServerError.custom(string: "Parse Failed Event Properties")
            handleEventProperties(subscription: subscription, properties: nil, error: err)
            throw err
        }
        
        handleEventProperties(subscription: subscription, properties: properties, error: nil)
        response.code = 200
    }

    func handleEventProperties(subscription: UPnPEventSubscription?, properties: UPnPEventProperties?, error: Error?) {
        for notificationHandler in eventNotificationHandlers {
            notificationHandler(subscription, properties, error)
        }
    }

    /**
     Start SSDP Receiver
     */
    public func startSsdpReceiver() {

        DispatchQueue.global(qos: .default).async {
            
            guard self.ssdpReceiver == nil else {
                return
            }
            self.ssdpReceiver = SSDPReceiver() {
                (address, ssdpHeader) in
                guard let ssdpHeader = ssdpHeader else {
                    return nil
                }
                return self.onSSDPHeader(address: address, ssdpHeader: ssdpHeader)
            }
            do {
                try self.ssdpReceiver!.run()
            } catch let error {
                print("UPnPControlPoint::startSsdpReceiver() error - error - \(error)")
            }
            self.ssdpReceiver = nil
        }
    }

    func startTimer() throws {
        let queue = DispatchQueue(label: "com.tjapp.upnp.timer")
        timer = DispatchSource.makeTimerSource(queue: queue)
        guard let timer = timer else {
            throw UPnPError.custom(string: "Failed DispatchSource.makeTimerSource")
        }
        timer.schedule(deadline: .now(), repeating: 10.0, leeway: .seconds(0))
        timer.setEventHandler { () in
            self.removeExpiredDevices()
            self.removeExpiredSubscriber()
        }
        timer.resume()
    }

    /**
     Stop UPnP Control Point
     */
    public func finish() {
        timer?.cancel()
        httpServer?.finish()
        ssdpReceiver?.finish()
    }

    /**
     Send M-SEARCH with ST (Service Type) and MX (Max)
     */
    public func sendMsearch(st: String, mx: Int) {

        DispatchQueue.global(qos: .default).async {

            SSDP.sendMsearch(st: st, mx: mx) {
                (address, ssdpHeader) in
                guard let ssdpHeader = ssdpHeader else {
                    return
                }
                self.onSSDPHeader(address: address, ssdpHeader: ssdpHeader)
            }
        }
    }

    /**
     On SSDP Header is received
     */
    @discardableResult public func onSSDPHeader(address: (String, Int32)?, ssdpHeader: SSDPHeader) -> [SSDPHeader]? {
        if ssdpHeader.isNotify {
            guard let nts = ssdpHeader.nts else {
                return nil
            }
            switch nts {
            case .alive:
                guard let usn = ssdpHeader.usn else {
                    break
                }
                if let device = self.devices[usn.uuid] {
                    device.renewTimeout()
                } else if let location = ssdpHeader["LOCATION"] {
                    if let url = URL(string: location) {
                        devices[usn.uuid] = UPnPDevice(timeout: 15)
                        buildDevice(url: url)
                    }
                }
                break
            case .byebye:
                if let usn = ssdpHeader.usn {
                    self.removeDevice(udn: usn.uuid)
                }
                break
            case .update:
                if let usn = ssdpHeader.usn {
                    if let device = self.devices[usn.uuid] {
                        device.renewTimeout()
                    }
                }
                break
            }
        } else if ssdpHeader.isHttpResponse {
            guard let usn = ssdpHeader.usn else {
                return nil
            }
            if let device = self.devices[usn.uuid] {
                device.renewTimeout()
            } else if let location = ssdpHeader["LOCATION"] {
                if let url = URL(string: location) {
                    devices[usn.uuid] = UPnPDevice(timeout: 15)
                    buildDevice(url: url)
                }
            }
        }
        return nil
    }

    func buildDevice(url: URL) {
        UPnPDeviceBuilder(delegate: self) {
            (device, service, scpd, error) in 
            for handler in self.onScpdHandlers {
                handler(device, service, scpd, error)
            }
        }.build(url: url)
    }

    /**
     On Device Build with URL and Device
     */
    public func onDeviceBuild(url: URL?, device: UPnPDevice?) {
        guard let device = device else {
            return
        }
        addDevice(device: device)
    }

    /**
     On Device Build Error
     */
    public func onDeviceBuildError(error: String?) {
        print("[UPnPControlPoint] Device Build Error - \(error ?? "nil")")
    }

    /**
     Add Handler: On Device Added
     */
    public func onDeviceAdded(handler: ((UPnPDevice) -> Void)?) {
        guard let handler = handler else {
            return
        }
        onDeviceAddedHandlers.append(handler)
    }

    /**
     Add Handler: On Device Removed
     */
    public func onDeviceRemoved(handler: ((UPnPDevice) -> Void)?) {
        guard let handler = handler else {
            return
        }
        onDeviceRemovedHandlers.append(handler)
    }

    /**
     Add Handler: On Scpd
     */
    func onScpd(handler: (scpdHandler)?) {
        guard let handler = handler else {
            return
        }
        onScpdHandlers.append(handler)
    }

    /**
     Add device with Device
     */
    public func addDevice(device: UPnPDevice) {
        guard let udn = device.udn else {
            return
        }
        devices[udn] = device
        if let delegate = self.delegate {
            delegate.onDeviceAdded(device: device)
        }
        for handler in onDeviceAddedHandlers {
            handler(device)
        }
    }

    /**
     Remove Device with UDN
     */
    public func removeDevice(udn: String) {
        guard let device = devices[udn] else {
            return
        }
        if let delegate = self.delegate {
            delegate.onDeviceRemoved(device: device)
        }
        for handler in onDeviceRemovedHandlers {
            handler(device)
        }
        devices[udn] = nil
    }

    /**
     Invoek with Service and actionRequest
     */
    public func invoke(service: UPnPService, actionRequest: UPnPActionRequest, completionHandler: (UPnPActionInvokeDelegate)?) {
        return self.invoke(service: service, actionName: actionRequest.actionName, fields: actionRequest.fields, completionHandler: completionHandler);
    }

    /**
     Invoke with Service and action, properties, completionHandler (Optional)
     */
    public func invoke(service: UPnPService, actionName: String, fields: OrderedProperties, completionHandler: (UPnPActionInvokeDelegate)?) {
        guard let serviceType = service.serviceType else {
            print("UPnPControlPoint::invoke() error - no service type")
            return
        }
        let soapRequest = UPnPSoapRequest(serviceType: serviceType, actionName: actionName)
        for field in fields.fields {
            soapRequest[field.key] = field.value
        }
        guard let controlUrl = service.controlUrl, let device = service.device else {
            print("UPnPControlPoint::invoke() error - no control url or no device")
            return
        }
        guard let url = URL(string: controlUrl, relativeTo: device.rootDevice.baseUrl) else {
            print("UPnPControlPoint::invoke() error - url failed")
            return
        }
        UPnPActionInvoke(url: url, soapRequest: soapRequest, completionHandler: completionHandler).invoke()
    }

    /**
     Subscribe with service
     */
    @discardableResult public func subscribe(udn: String, service: UPnPService, completionHandler: (eventSubscribeCompleteHandler)? = nil) -> UPnPEventSubscriber? {
        guard let callbackUrls = makeCallbackUrl(udn: udn, service: service) else {
            return nil
        }
        let subscriber = UPnPEventSubscriber(udn: udn, service: service, callbackUrls: [callbackUrls])
        subscriber.subscribe {
            (subscription, error) in

            completionHandler?(subscription, error)

            if error == nil && subscription != nil {
                self.eventSubscribers.append(subscriber)
            }
        }
        return subscriber
    }

    func removeExpiredDevices() {
        devices = devices.filter { $1.isExpired == false }
    }

    func removeExpiredSubscriber() {
        eventSubscribers = eventSubscribers.filter { $0.isExpired == false }
    }

    func makeCallbackUrl(udn: String, service: UPnPService) -> URL? {
        
        guard let httpServer = self.httpServer else {
            return nil
        }

        guard let httpServerAddress = httpServer.serverAddress else {
            return nil
        }

        guard let addr = Network.getInetAddress() else {
            return nil
        }
        let hostname = addr.hostname
        return URL(string: "http://\(hostname):\(httpServerAddress.port)/notify/\(udn)/\(service.serviceId ?? "nil")")
    }
}
