import Foundation
import swift_http_server

public class UPnPControlPoint {

    var port: Int
    var httpServer : HttpServer?
    var ssdpReceiver : SSDPReceiver?
    var ssdpHandler : SSDPHandlerClosure?

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
                    break
                case .byebye:
                    break
                case .update:
                    break
                }
            }
            return nil
        }
    }

    func addDevice(device: UPnPDevice) {
    }

    func removeDevice(udn: String) {
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
