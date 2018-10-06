import Foundation
import SwiftHttpServer

public protocol UPnPControlPointDelegate {
    func onDeviceAdded(device: UPnPDevice)
    func onDeviceRemoved(device: UPnPDevice)
}


public class UPnPControlPoint {

    public var port: Int
    public var httpServer : HttpServer?
    public var ssdpReceiver : SSDPReceiver?
    public var devices = [UPnPDevice]()
    public var delegate: UPnPControlPointDelegate?
    public var eventSubscribers = [UPnPEventSubscriber]()
    public var eventPropertyLisetner: ((String, UPnPEventProperties) -> Void)?
    var onDeviceAddedHandlers = [(UPnPDevice) -> Void]()
    var onDeviceRemovedHandlers = [(UPnPDevice) -> Void]()
    var timer: DispatchSourceTimer?
    
    public init(port: Int, eventPropertyLisetner: ((String, UPnPEventProperties) -> Void)? = nil) {
        self.port = port
        self.eventPropertyLisetner = eventPropertyLisetner
    }

    deinit {
        finish()
    }

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

    public func run() {
        startHttpServer()
        startSsdpReceiver()
        startTimer()
    }

    public func getDevice(udn: String) -> UPnPDevice? {
        for device in devices {
            guard let device_udn = device.udn else {
                continue
            }
            if device_udn == udn {
                return device
            }
        }
        return nil
    }

    public func setDevice(device: UPnPDevice) {
        removeDevice(device: device)
        devices.append(device)
    }

    public func removeDevice(device: UPnPDevice) {
        devices = devices.filter { ($0.udn != nil) && (device.udn != nil) && ($0.udn! != device.udn!) }
    }

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
                        print("no request")
                        return nil
                    }
                    print("path -- \(request.path)")
                    guard let sid = request.header["sid"] else {
                        print("no sid")
                        return nil
                    }

                    guard let contentLength = request.header.contentLength else {
                        print("no content length")
                        return nil
                    }

                    guard contentLength > 0 else {
                        print("content length -- \(contentLength)")
                        return nil
                    }

                    var data = Data(capacity: contentLength)
                    guard try request.remoteSocket?.read(into: &data) == contentLength else {
                        print("socket read() -- failed")
                        return nil
                    }

                    guard let xmlString = String(data: data, encoding: .utf8) else {
                        print("xml string failed")
                        return nil
                    }

                    guard let properties = UPnPEventProperties.read(xmlString: xmlString) else {
                        print("not event properties")
                        return nil
                    }

                    print("sid -- \(sid)")

                    self.eventPropertyLisetner?(sid, properties)
                    
                    return HttpResponse(code: 200)
                }
                try self.httpServer!.run()
            } catch let error{
                print("error - \(error)")
            }
            self.httpServer = nil
        }
    }

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
                print("error - \(error)")
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

    public func finish() {
        timer?.cancel()
        httpServer?.finish()
        ssdpReceiver?.finish()
    }

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
                if let device = self.getDevice(udn: usn.uuid) {
                    device.renewTimeout()
                } else if let location = ssdpHeader["LOCATION"] {
                    if let url = URL(string: location) {
                        setDevice(device: UPnPDevice(udn: usn.uuid, timeout: 15))
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
                    if let device = getDevice(udn: usn.uuid) {
                        device.renewTimeout()
                    }
                }
                break
            }
        } else if ssdpHeader.isHttpResponse {
            guard let usn = ssdpHeader.usn else {
                return nil
            }
            if let device = getDevice(udn: usn.uuid) {
                device.renewTimeout()
            } else if let location = ssdpHeader["LOCATION"] {
                if let url = URL(string: location) {
                    setDevice(device: UPnPDevice(udn: usn.uuid, timeout: 15))
                    buildDevice(url: url)
                }
            }
        }
        return nil
    }

    func buildDevice(url: URL) {
        UPnPDeviceBuilder() {
            (device) in
            guard let device = device else {
                print("no device build")
                return
            }
            self.addDevice(device: device)
        }.build(url: url)
    }

    public func onDeviceAdded(handler: ((UPnPDevice) -> Void)?) {
        guard let handler = handler else {
            return
        }
        onDeviceAddedHandlers.append(handler)
    }

    public func onDeviceRemoved(handler: ((UPnPDevice) -> Void)?) {
        guard let handler = handler else {
            return
        }
        onDeviceRemovedHandlers.append(handler)
    }

    public func addDevice(device: UPnPDevice) {
        guard let device_udn = device.udn else {
            return
        }
        if let device = getDevice(udn: device_udn) {
            guard device.status == .initialized else {
                return
            }
        }
        
        setDevice(device: device)
        device.status = .completed
        if let delegate = delegate {
            delegate.onDeviceAdded(device: device)
        }
        for handler in onDeviceAddedHandlers {
            handler(device)
        }
    }

    public func removeDevice(udn: String) {
        guard let device = getDevice(udn: udn) else {
            return
        }
        if let delegate = delegate {
            delegate.onDeviceRemoved(device: device)
        }
        for handler in onDeviceRemovedHandlers {
            handler(device)
        }
        removeDevice(device: device)
    }

    public func invoke(service: UPnPService, action: UPnPAction, properties: [String:String], completeHandler: ((UPnPSoapResponse?) -> Void)?) {
        guard let actionName = action.name else {
            print("no action name")
            return
        }
        invoke(service: service, action: actionName, properties: OrderedProperties(fromDict: properties), completeHandler: completeHandler)
    }

    public func invoke(service: UPnPService, action: String, properties: OrderedProperties, completeHandler: ((UPnPSoapResponse?) -> Void)?) {
        guard let serviceType = service.serviceType else {
            print("error -- no service type")
            return
        }
        let soapRequest = UPnPSoapRequest(serviceType: serviceType, actionName: action)
        for field in properties.fields {
            soapRequest[field.key] = field.value
        }
        guard let controlUrl = service.controlUrl, let device = service.device else {
            print("error -- no control url or no device")
            return
        }
        guard let url = URL(string: controlUrl, relativeTo: device.rootDevice.baseUrl) else {
            print("error -- url failed")
            return
        }
        UPnPActionInvoke(url: url, soapRequest: soapRequest, completeHandler: completeHandler).invoke()
    }

    public func onEventProperty(listener: ((String, UPnPEventProperties) -> Void)?) {
        eventPropertyLisetner = listener
    }

    @discardableResult public func subscribe(service: UPnPService, completeListener: ((UPnPEventSubscription) -> Void)? = nil) -> UPnPEventSubscriber? {
        guard let callbackUrls = getCallbackUrl(of: service) else {
            return nil
        }
        let subscriber = UPnPEventSubscriber(service: service, callbackUrls: [callbackUrls])
        subscriber.subscribe(completeListener: completeListener)
        return subscriber
    }

    func removeExpiredDevices() {
        devices = devices.filter { $0.isExpired == false }
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
