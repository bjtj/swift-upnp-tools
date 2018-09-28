import Foundation
import SwiftHttpServer

public class UPnPServer {

    public var port: Int
    public var httpServer: HttpServer?
    public var ssdpReceiver: SSDPReceiver?
    public var devices = [String:UPnPDevice]()
    public var subscriptions = [String:UPnPEventSubscription]()


    public init(port: Int) {
        self.port = port
    }

    public func registerDevice(device: UPnPDevice) {
    }

    public func unregisterDevice(device: UPnPDevice) {
    }

    public func activate(device: UPnPDevice) {
        guard let serviceTypes = device.allServiceTypes else {
            return
        }
        for usn in serviceTypes {
            let properties = OrderedProperties()
            properties["NTS"] = "ssdp:alive"
            properties["NT"] = usn.type
            properties["USN"] = usn.uuid
            SSDP.notify(properties: properties)
        }
    }

    public func deactivate(device: UPnPDevice) {
        guard let serviceTypes = device.allServiceTypes else {
            return
        }
        for usn in serviceTypes {
            let properties = OrderedProperties()
            properties["NTS"] = "ssdp:byebye"
            properties["NT"] = usn.type
            properties["USN"] = usn.uuid
            SSDP.notify(properties: properties)
        }
    }

    public func registerEventSubscription(subscription: UPnPEventSubscription) {
        subscriptions[subscription.sid] = subscription
    }

    public func unregisterEventSubscription(subscription: UPnPEventSubscription) {
        subscriptions[subscription.sid] = nil
    }

    public func run() {
        startHttpServer()
        startSsdpReceiver()
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

    public func onSSDPHeader(address: InetAddress?, ssdpHeader: SSDPHeader?) -> [SSDPHeader]? {
        guard let ssdpHeader = ssdpHeader else {
            return nil
        }
        if ssdpHeader.isMsearch {
            if let st = ssdpHeader["ST"] {
                print("msearch received / st: \(st)")
            }
            // send response
        }
        return nil
    }
}
