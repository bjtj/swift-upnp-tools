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
 UPnP Control Point Implementation
 */
public class UPnPControlPoint : UPnPDeviceBuilderDelegate {

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
    public var delegate: UPnPControlPointDelegate?
    /**
     event subscribers
     */
    public var eventSubscribers = [UPnPEventSubscriber]()
    /**
     event property listener
     */
    public var eventPropertyLisetner: ((String, UPnPEventProperties) -> Void)?
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
    var onScpdHandlers = [(UPnPService, UPnPScpd) -> Void]()

    /**
     timer
     */
    var timer: DispatchSourceTimer?
    
    public init(httpServerBindPort: Int, eventPropertyLisetner: ((String, UPnPEventProperties) -> Void)? = nil) {
        self.port = httpServerBindPort
        self.eventPropertyLisetner = eventPropertyLisetner
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
    public func run() {
        startHttpServer()
        startSsdpReceiver()
        startTimer()
    }

    /**
     Get device with UDN
     */
    public func getDevice(udn: String) -> UPnPDevice? {
        return devices[udn]
    }

    /**
     Start HTTP Server
     */
    public func startHttpServer() {
        DispatchQueue.global(qos: .background).async {
            guard self.httpServer == nil else {
                // already started
                return
            }
            do {
                self.httpServer = HttpServer(port: self.port)
                try self.httpServer!.route(pattern: "/notify") {
                    (request) in
                    guard let request = request else {
                        print("UPnPControlPoint: no request")
                        return nil
                    }
                    print("UPnPControlPoint: path -- \(request.path)")
                    guard let sid = request.header["sid"] else {
                        print("UPnPControlPoint: no sid")
                        return nil
                    }

                    guard let contentLength = request.header.contentLength else {
                        print("UPnPControlPoint: no content length")
                        return nil
                    }

                    guard contentLength > 0 else {
                        print("UPnPControlPoint: content length -- \(contentLength)")
                        return nil
                    }

                    var data = Data(capacity: contentLength)
                    guard try request.remoteSocket?.read(into: &data) == contentLength else {
                        print("UPnPControlPoint: socket read() -- failed")
                        return nil
                    }

                    guard let xmlString = String(data: data, encoding: .utf8) else {
                        print("UPnPControlPoint: xml string failed")
                        return nil
                    }

                    guard let properties = UPnPEventProperties.read(xmlString: xmlString) else {
                        print("UPnPControlPoint: not event properties")
                        return nil
                    }

                    print("UPnPControlPoint: sid -- \(sid)")

                    self.eventPropertyLisetner?(sid, properties)
                    
                    return HttpResponse(code: 200)
                }
                try self.httpServer!.run()
            } catch let error{
                print("UPnPControlPoint: error - \(error)")
            }
            self.httpServer = nil
        }
    }

    /**
     Start SSDP Receiver
     */
    public func startSsdpReceiver() {
        DispatchQueue.global(qos: .background).async {
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
                print("UPnPControlPoint: error - \(error)")
            }
            self.ssdpReceiver = nil
        }
    }

    func startTimer() {
        let queue = DispatchQueue(label: "com.tjapp.upnp.timer")
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: 10.0, leeway: .seconds(0))
        timer?.setEventHandler { () in
            self.removeExpiredDevices()
            self.removeExpiredSubscriber()
        }
        timer?.resume()
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
        DispatchQueue.global(qos: .background).async {
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
            (service, scpd) in 
            for handler in self.onScpdHandlers {
                handler(service, scpd)
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
    func onScpd(handler: ((UPnPService, UPnPScpd) -> Void)?) {
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
    public func invoke(service: UPnPService, actionRequest: UPnPActionRequest, completeHandler: ((UPnPSoapResponse?) -> Void)?) {
        return self.invoke(service: service, actionName: actionRequest.actionName, fields: actionRequest.fields, completeHandler: completeHandler);
    }

    /**
     Invoke with Service and action, properties, completeHandler (Optional)
     */
    public func invoke(service: UPnPService, actionName: String, fields: OrderedProperties, completeHandler: ((UPnPSoapResponse?) -> Void)?) {
        guard let serviceType = service.serviceType else {
            print("UPnPControlPoint: error -- no service type")
            return
        }
        let soapRequest = UPnPSoapRequest(serviceType: serviceType, actionName: actionName)
        for field in fields.fields {
            soapRequest[field.key] = field.value
        }
        guard let controlUrl = service.controlUrl, let device = service.device else {
            print("UPnPControlPoint: error -- no control url or no device")
            return
        }
        guard let url = URL(string: controlUrl, relativeTo: device.rootDevice.baseUrl) else {
            print("UPnPControlPoint: error -- url failed")
            return
        }
        UPnPActionInvoke(url: url, soapRequest: soapRequest, completeHandler: completeHandler).invoke()
    }

    /**
     On Event Property with listener (Optional)
     */
    public func onEventProperty(listener: ((String, UPnPEventProperties) -> Void)?) {
        eventPropertyLisetner = listener
    }

    /**
     Subscribe with service and completeListener (Optional)
     */
    @discardableResult public func subscribe(service: UPnPService, completeListener: ((UPnPEventSubscription) -> Void)? = nil) -> UPnPEventSubscriber? {
        guard let callbackUrls = getCallbackUrl(of: service) else {
            return nil
        }
        let subscriber = UPnPEventSubscriber(service: service, callbackUrls: [callbackUrls])
        subscriber.subscribe(completeListener: completeListener)
        return subscriber
    }

    func removeExpiredDevices() {
        devices = devices.filter { $1.isExpired == false }
    }

    func removeExpiredSubscriber() {
        eventSubscribers = eventSubscribers.filter { $0.isExpired == false }
    }

    func getCallbackUrl(of service: UPnPService) -> URL? {
        
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
        return URL(string: "http://\(hostname):\(httpServerAddress.port)/notify")
    }
}
