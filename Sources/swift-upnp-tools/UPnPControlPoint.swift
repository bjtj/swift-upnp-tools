import Foundation
import SwiftHttpServer

public protocol DeviceHandlerProtocol {
    func onDeviceAdded(device: UPnPDevice)
    func onDeviceRemoved(device: UPnPDevice)
}

public class UPnPControlPoint : OnDeviceBuildProtocol {

    public var port: Int
    public var httpServer : HttpServer?
    public var ssdpReceiver : SSDPReceiver?
    public var devices = [String:UPnPDevice]()
    public var deviceHandler: DeviceHandlerProtocol?
    public var subscriptions = [String:UPnPEventSubscription]()
    
    public init(port: Int) {
        self.port = port
    }

    public func run() {
        startHttpServer()
        startSsdpReceiver()
    }

    public func getDevice(udn: String) -> UPnPDevice? {
        return devices[udn]
    }

    public func startHttpServer() {
        DispatchQueue.global(qos: .default).async {
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
                print("error - \(error)")
            }
            self.ssdpReceiver = nil
        }
    }

    public func finish() {
        if let httpServer = httpServer {
            httpServer.finish()
        }
        if let ssdpReceiver = ssdpReceiver {
            ssdpReceiver.finish()
        }
    }

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

    @discardableResult public func onSSDPHeader(address: InetAddress?, ssdpHeader: SSDPHeader) -> [SSDPHeader]? {
        if ssdpHeader.isNotify {
            guard let nts = ssdpHeader.nts else {
                return nil
            }
            switch nts {
            case .alive:
                if let usn = ssdpHeader.usn {
                    if let device = self.devices[usn.uuid] {
                        device.renewTimeout()
                    }
                }
                if let location = ssdpHeader["LOCATION"] {
                    if let url = URL(string: location) {
                        buildDevice(url: url, deviceHandler: self)
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
        }
        if ssdpHeader.isHttpResponse {
            if let usn = ssdpHeader.usn {
                if let device = self.devices[usn.uuid] {
                    device.renewTimeout()
                }
            }
            if let location = ssdpHeader["LOCATION"] {
                if let url = URL(string: location) {
                    buildDevice(url: url, deviceHandler: self)
                }
            }
        }
        return nil
    }

    public func onDeviceBuild(url: URL?, device: UPnPDevice?) {
        guard let device = device, let url = url else {
            return
        }
        device.baseUrl = url
        addDevice(device: device)
    }

    func addDevice(device: UPnPDevice) {
        guard let udn = device.udn else {
            return
        }
        devices[udn] = device
        if let deviceHandler = deviceHandler {
            deviceHandler.onDeviceAdded(device: device)
        }
    }

    func removeDevice(udn: String) {
        if let device = devices[udn], let deviceHandler = deviceHandler {
            deviceHandler.onDeviceRemoved(device: device)
        }
        devices[udn] = nil
    }

    public func invokeAction(url: URL, soapRequest: UPnPSoapRequest, handler: SoapResponseDelegate?) {
        UPnPActionInvoke(url: url, soapRequest: soapRequest, handler: handler).invoke()
    }

    public func getSubscription(sid: String) -> UPnPEventSubscription? {
        return subscriptions[sid]
    }

    public func subscribe(url: URL) {
        subscribeEvent(url: url, callbackUrls: []) {
            (subscription) in
            guard let subscription = subscription else {
                return
            }
            self.subscriptions[subscription.sid] = subscription
        }
    }

    public func renewSubscribe(url: URL, subscription: UPnPEventSubscription) {
        renewEventSubscription(url: url, subscription: subscription) {
            (subscription) in
            guard let subscription = subscription else {
                return
            }
            subscription.renewTimeout()
        }
    }

    public func unsubscribe(url: URL, subscription: UPnPEventSubscription) {
        unsubscribeEvent(url: url, subscription: subscription) {
            (subscription) in
            guard let subscription = subscription else {
                return
            }
            self.subscriptions[subscription.sid] = nil
        }
        
    }

}
