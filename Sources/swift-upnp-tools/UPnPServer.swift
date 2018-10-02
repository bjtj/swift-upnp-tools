import Foundation
import SwiftHttpServer


public class UPnPServer {

    public var port: Int
    public var httpServer: HttpServer?
    public var ssdpReceiver: SSDPReceiver?
    public var devices = [String:UPnPDevice]()
    public var subscriptions = [String:UPnPEventSubscription]()
    var onActionRequestHandler: ((UPnPService, UPnPSoapRequest) -> OrderedProperties?)?

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
        guard let location = getLocation(of: device) else {
            return
        }
        UPnPServer.activate(device: device, location: location)
    }

    public class func activate(device: UPnPDevice, location: String) {
        guard let usn_list = device.allServiceTypes else {
            return
        }
        guard let udn = device.udn else {
            return
        }
        notifyAlive(usn: UPnPUsn(uuid: udn, type: "upnp:rootDevice"), location: location)
        for usn in usn_list {
            notifyAlive(usn: usn, location: location)
        }
        notifyAlive(usn: UPnPUsn(uuid: udn), location: location)
    }

    class func notifyAlive(usn: UPnPUsn, location: String) {
        let properties = OrderedProperties()
        properties["HOST"] = "\(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)"
        properties["CACHE-CONTROL"] = "max-age=1800"
        properties["NTS"] = "ssdp:alive"
        properties["NT"] = usn.type.isEmpty ? usn.uuid : usn.type
        properties["USN"] = usn.description
        properties["LOCATION"] = location
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
        guard let udn = device.udn else {
            return
        }
        notifyByebye(usn: UPnPUsn(uuid: udn, type: "upnp:rootDevice"))
        for usn in usn_list {
            notifyByebye(usn: usn)
        }
        notifyByebye(usn: UPnPUsn(uuid: udn))
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

    public func onActionRequest(handler: ((UPnPService, UPnPSoapRequest) -> OrderedProperties?)?) {
        onActionRequestHandler = handler
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
            do {
                self.httpServer = HttpServer(port: self.port)
                try self.httpServer!.route(pattern: "/.*") {
                    (request) in
                    guard let request = request else {
                        print("no request")
                        return nil
                    }
                    print("path -- \(request.path)")
                    if request.path.hasSuffix("device.xml") {
                        let response = HttpResponse(code: 200, reason: "OK")
                        let tokens = request.path.split(separator: "/")
                        guard tokens.isEmpty == false else {
                            return nil
                        }
                        let udn = String(tokens[0])
                        guard let device = self.devices[udn] else {
                            return nil
                        }
                        response.data = device.xmlDocument.data(using: .utf8)
                        return response
                    } else if request.path.hasSuffix("scpd.xml") {
                        for (_, device) in self.devices {
                            if let service = device.getService(withScpdUrl: request.path) {
                                guard let scpd = service.scpd else {
                                    continue
                                }
                                let response = HttpResponse(code: 200, reason: "OK")
                                response.data = scpd.xmlDocument.data(using: .utf8)
                                return response
                            }
                        }
                        return nil
                    } else if request.path.hasSuffix("control.xml") {

                        print("action request -- \(request.path)")
                        
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
                            print("sockte read() -- failed")
                            return nil
                        }

                        guard let xmlString = String(data: data, encoding: .utf8) else {
                            print("xml string failed")
                            return nil
                        }

                        guard let soapRequest = UPnPSoapRequest.read(xmlString: xmlString) else {
                            print("not soap request -- \(xmlString)")
                            return nil
                        }

                        guard let handler = self.onActionRequestHandler else {
                            print("no handler")
                            return nil
                        }
                        
                        for (_, device) in self.devices {
                            if let service = device.getService(withControlUrl: request.path) {
                                guard let properties = handler(service, soapRequest) else {
                                    continue
                                }
                                let soapResponse = UPnPSoapResponse(serviceType: soapRequest.serviceType, actionName: soapRequest.actionName)
                                for field in properties.fields {
                                    soapResponse[field.key] = field.value
                                }
                                let response = HttpResponse(code: 200, reason: "OK")
                                response.data = soapResponse.xmlDocument.data(using: .utf8)
                                return response
                            }
                        }
                        return nil
                    } else if request.path.hasSuffix("event.xml") {
                    } else {
                        print("unknown request -- \(request.path)")
                    }
                    return nil
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
                var responses = [SSDPHeader]()
                switch st {
                case "ssdp:all":
                    for (udn, device) in devices {
                        guard let location = getLocation(of: device) else {
                            continue
                        }
                        let rootDevice = UPnPUsn(uuid: udn, type: "upnp:rootDevice")
                        responses.append(makeMsearchResponse(from: rootDevice, location: location))
                        guard let usn_list = device.allServiceTypes else {
                            continue
                        }
                        for usn in usn_list {
                            responses.append(makeMsearchResponse(from: usn, location: location))
                        }
                        responses.append(makeMsearchResponse(from: UPnPUsn(uuid: udn), location: location))
                    }
                case "upnp:rootDevice":
                    for (udn, device) in devices {
                        guard let location = getLocation(of: device) else {
                            continue
                        }
                        let usn = UPnPUsn(uuid: udn, type: st)
                        responses.append(makeMsearchResponse(from: usn, location: location))
                    }
                default:
                    for (udn, device) in devices {
                        guard let location = getLocation(of: device) else {
                            continue
                        }
                        if let _ = device.getDevice(type: st) {
                            let usn = UPnPUsn(uuid: udn, type: st)
                            responses.append(makeMsearchResponse(from: usn, location: location))
                        }
                        if let _ = device.getService(type: st) {
                            let usn = UPnPUsn(uuid: udn, type: st)
                            responses.append(makeMsearchResponse(from: usn, location: location))
                        }
                    }
                    break
                }
                return responses
            }
        }
        return nil
    }

    func makeMsearchResponse(from usn: UPnPUsn, location: String) -> SSDPHeader {
        let header = SSDPHeader()
        header.firstLine = "HTTP/1.1 200 OK"
        header["CACHE-CONTROL"] = "max-age=1800"
        header["ST"] = usn.type.isEmpty ? usn.uuid : usn.type
        header["USN"] = usn.description
        header["LOCATION"] = location
        return header
    }

    func getLocation(of device: UPnPDevice) -> String? {
        guard let httpServer = self.httpServer else {
            return nil
        }
        guard let udn = device.udn else {
            return nil
        }
        guard let addr = httpServer.serverAddress else {
            return nil
        }
        let hostname = "127.0.0.1"
        let location = "http://\(hostname):\(addr.port)/\(udn)/device.xml"
        return location
    }

    public func setProperty(service: UPnPService, properties: [String:String]) {
    }
}
