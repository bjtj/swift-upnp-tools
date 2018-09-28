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
        guard let udn = device.udn else {
            return
        }
        devices[udn] = device
    }

    public func unregisterDevice(device: UPnPDevice) {
        guard let udn = device.udn else {
            return
        }
        devices[udn] = nil
    }

    public func activate(udn: String) {
        guard let device = devices[udn] else {
            return
        }
        UPnPServer.activate(device: device)
    }

    public class func activate(device: UPnPDevice) {
        guard let usn_list = device.allServiceTypes else {
            return
        }
        let location = "http://fake"
        notifyAlive(usn: UPnPUsn(uuid: device.udn!, type: "upnp:rootDevice"), location: location)
        for usn in usn_list {
            notifyAlive(usn: usn, location: location)
        }
        notifyAlive(usn: UPnPUsn(uuid: device.udn!), location: location)
    }

    class func notifyAlive(usn: UPnPUsn, location: String) {
        let properties = OrderedProperties()
        properties["HOST"] = "\(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)"
        properties["NTS"] = "ssdp:alive"
        properties["NT"] = usn.type.isEmpty ? usn.uuid : usn.type
        properties["USN"] = usn.description
        properties["Location"] = location
        SSDP.notify(properties: properties)
    }

    public func deactivate(udn: String) {
        guard let device = devices[udn] else {
            return
        }
        UPnPServer.deactivate(device: device)
    }

    public class func deactivate(device: UPnPDevice) {
        guard let usn_list = device.allServiceTypes else {
            return
        }
        notifyByebye(usn: UPnPUsn(uuid: device.udn!, type: "upnp:rootDevice"))
        for usn in usn_list {
            notifyByebye(usn: usn)
        }
        notifyByebye(usn: UPnPUsn(uuid: device.udn!))
    }

    public class func notifyByebye(usn: UPnPUsn) {
        let properties = OrderedProperties()
        properties["HOST"] = "\(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)"
        properties["NTS"] = "ssdp:byebye"
        properties["NT"] = usn.type.isEmpty ? usn.uuid : usn.type
        properties["USN"] = usn.description
        SSDP.notify(properties: properties)
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
