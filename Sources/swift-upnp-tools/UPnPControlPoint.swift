import Foundation
import SwiftHttpServer

public protocol UPnPControlPointDelegate {
    func onDeviceAdded(device: UPnPDevice)
    func onDeviceRemoved(device: UPnPDevice)
}

public protocol UPnPEventPropertyDelegate {
    func onEventProperty(properties: UPnPEventProperties)
}

public class UPnPControlPoint : UPnPDeviceBuilderDelegate {

    public var port: Int
    public var httpServer : HttpServer?
    public var ssdpReceiver : SSDPReceiver?
    public var devices = [String:UPnPDevice]()
    public var delegate: UPnPControlPointDelegate?
    public var eventSubscribers = [UPnPEventSubscriber]()
    public var eventPropertyDelegate: UPnPEventPropertyDelegate?
    var onDeviceAddedHandlers = [(UPnPDevice) -> Void]()
    var onDeviceRemovedHandlers = [(UPnPDevice) -> Void]()
    var timer: DispatchSourceTimer?
    
    public init(port: Int) {
        self.port = port
    }

    deinit {
        finish()
    }

    public func run() {
        startHttpServer()
        startSsdpReceiver()
        startTimer()
    }

    public func getDevice(udn: String) -> UPnPDevice? {
        return devices[udn]
    }

    public func startHttpServer() {
        DispatchQueue.global(qos: .background).async {
            guard self.httpServer == nil else {
                // already started
                return
            }
            self.httpServer = HttpServer(port: self.port)
            do {
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

    @discardableResult public func onSSDPHeader(address: InetAddress?, ssdpHeader: SSDPHeader) -> [SSDPHeader]? {
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
        UPnPDeviceBuilder(delegate: self).build(url: url)
    }

    public func onDeviceBuild(url: URL?, device: UPnPDevice?) {
        guard let device = device, let url = url else {
            return
        }
        device.baseUrl = url
        addDevice(device: device)
    }

    func onDeviceAdded(handler: ((UPnPDevice) -> Void)?) {
        guard let handler = handler else {
            return
        }
        onDeviceAddedHandlers.append(handler)
    }

    func onDeviceRemoved(handler: ((UPnPDevice) -> Void)?) {
        guard let handler = handler else {
            return
        }
        onDeviceRemovedHandlers.append(handler)
    }

    func addDevice(device: UPnPDevice) {
        guard let udn = device.udn else {
            return
        }
        devices[udn] = device
        if let delegate = delegate {
            delegate.onDeviceAdded(device: device)
        }
        for handler in onDeviceAddedHandlers {
            handler(device)
        }
    }

    func removeDevice(udn: String) {
        guard let device = devices[udn] else {
            return
        }
        if let delegate = delegate {
            delegate.onDeviceRemoved(device: device)
        }
        for handler in onDeviceRemovedHandlers {
            handler(device)
        }
        devices[udn] = nil
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

    public func subscribe(service: UPnPService) -> UPnPEventSubscriber? {
        guard let callbackUrls = getCallbackUrl(of: service) else {
            return nil
        }
        let subscriber = UPnPEventSubscriber(service: service, callbackUrls: [callbackUrls])
        subscriber.subscribe()
        return subscriber
    }

    func removeExpiredDevices() {
        devices = devices.filter { $1.isExpired == false }
    }

    func removeExpiredSubscriber() {
        eventSubscribers = eventSubscribers.filter { $0.isExpired == false }
    }

    func getCallbackUrl(of service: UPnPService) -> URL? {

        guard let usn = service.usn else {
            return nil
        }
        
        guard let httpServer = self.httpServer else {
            return nil
        }

        guard let httpServerAddress = httpServer.serverAddress else {
            return nil
        }

        guard let addr = getInetAddress() else {
            return nil
        }
        let hostname = addr.hostname
        return URL(string: "http://\(hostname):\(httpServerAddress.port)/\(usn.description)/notify")
    }
}
