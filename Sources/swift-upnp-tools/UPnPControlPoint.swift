import Foundation
import SwiftHttpServer

public protocol DeviceHandlerProtocol {
    func onDeviceAdded(device: UPnPDevice)
    func onDeviceRemoved(device: UPnPDevice)
}

public class UPnPControlPoint : OnDeviceBuildProtocol, SSDPHandlerProtocol {

    public var port: Int
    public var httpServer : HttpServer?
    public var ssdpReceiver : SSDPReceiver?
    public var devices = [String:UPnPDevice]()
    public var deviceHandler: DeviceHandlerProtocol?
    public var subscriptions = [String:UPnPEventSubscription]()
    
    public init(port: Int) {
        self.port = port
    }

    public func onSSDPHeader(ssdpHeader: SSDPHeader) -> [SSDPHeader]? {
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
                if let location = ssdpHeader["location"] {
                    if let url = URL(string: location) {
                        buildDevice(url: url, handler: self)
                    }
                }
                break
            case .byebye:
                if let usn = ssdpHeader.usn {
                    self.removeDevice(udn: usn.uuid)
                }
                break
            case .update:
                break
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

    public func run() {
        DispatchQueue.global(qos: .background).async {
            self.httpServer = HttpServer(port: self.port)
            guard let server = self.httpServer else {
                return
            }
            do {
                try server.run()
            } catch let error{
                print("error - \(error)")
            }
            self.httpServer = nil
        }
        
        DispatchQueue.global(qos: .background).async {
            self.ssdpReceiver = SSDPReceiver()
            guard let receiver = self.ssdpReceiver else {
                return
            }
            receiver.handler = self
            do {
                try receiver.run()
            } catch let error {
                print("error - \(error)")
            }
            self.ssdpReceiver = nil
        }
    }

    public func finish() {
        if let server = httpServer {
            server.finish()
        }
        if let receiver = ssdpReceiver {
            receiver.finish()
        }
    }
}
