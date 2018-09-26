import Foundation
import swift_http_server

public protocol DeviceHandlerProtocol {
    func onDeviceAdded(device: UPnPDevice)
    func onDeviceRemoved(device: UPnPDevice)
}

public class UPnPControlPoint : OnDeviceBuildProtocol {

    public var port: Int
    public var httpServer : HttpServer?
    public var ssdpReceiver : SSDPReceiver?
    public var ssdpHandler : SSDPHandlerClosure?
    public var devices = [String:UPnPDevice]()
    public var deviceHandler: DeviceHandlerProtocol?
    
    public init(port: Int) {
        self.port = port
        ssdpHandler = { (ssdpHeader) in
            guard let ssdpHeader = ssdpHeader else {
                return nil
            }
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
                        let url = URL(string: location)
                        buildDevice(url: url, handler: self)
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
            receiver.handler = self.ssdpHandler
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
