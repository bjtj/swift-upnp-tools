//
// UPnPServer.swift
// 

import Foundation
import SwiftHttpServer

/**
 UPnP Server Implementation
 */
public class UPnPServer {

    /**
     http server bind port
     */
    public var port: Int
    /**
     http server
     */
    public var httpServer: HttpServer?
    /**
     ssdp receiver
     */
    public var ssdpReceiver: SSDPReceiver?
    /**
     upnp devices
     */
    public var devices = [String:UPnPDevice]()
    /**
     subscriptions
     */
    public var subscriptions = [String:UPnPEventSubscription]()
    /**
     on action request handler
     */
    var onActionRequestHandler: ((UPnPService, UPnPSoapRequest) -> OrderedProperties?)?

    public init(httpServerBindPort: Int) {
        self.port = httpServerBindPort
    }

    deinit {
        finish()
    }

    /**
     Get Event Subcscriptions with service
     */
    public func getEventSubscriptions(service: UPnPService) -> [UPnPEventSubscription] {
        var result = [UPnPEventSubscription]()
        for (_, subscription) in subscriptions {
            if subscription.service === service {
                result.append(subscription)
            }
        }
        return result
    }

    /**
     Register Devcie
     */
    public func registerDevice(device: UPnPDevice) {
        guard let udn = device.udn else {
            return
        }
        devices[udn] = device
    }

    /**
     Unregister Device
     */
    public func unregisterDevice(device: UPnPDevice) {
        guard let udn = device.udn else {
            return
        }
        devices[udn] = nil
    }

    /**
     Get Device with udn
     */
    public func getDevice(udn: String) -> UPnPDevice? {
        return devices[udn]
    }

    /**
     Activate device with UDN
     */
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

    /**
     Deactivate device with UDN
     */
    public func deactivate(udn: String) {
        guard let device = devices[udn] else {
            return
        }
        UPnPServer.deactivate(device: device)
    }

    /**
     Deactivate device with device
     */
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

    /**
     Notify Byebye
     */
    public class func notifyByebye(usn: UPnPUsn) {
        let properties = OrderedProperties()
        properties["HOST"] = "\(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)"
        properties["NTS"] = "ssdp:byebye"
        properties["NT"] = usn.type.isEmpty ? usn.uuid : usn.type
        properties["USN"] = usn.description
        SSDP.notify(properties: properties)
    }

    /**
     Register Event Subscription
     */
    public func registerEventSubscription(subscription: UPnPEventSubscription) {
        subscriptions[subscription.sid] = subscription
    }

    /**
     Unregister Event Subscription
     */
    public func unregisterEventSubscription(subscription: UPnPEventSubscription) {
        subscriptions[subscription.sid] = nil
    }

    /**
     On Action Request
     */
    public func onActionRequest(handler: ((UPnPService, UPnPSoapRequest) -> OrderedProperties?)?) {
        onActionRequestHandler = handler
    }

    /**
     Start UPnP Server
     */
    public func run() {
        startHttpServer()
        startSsdpReceiver()
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
                try self.httpServer!.route(pattern: "/.*") {
                    (request) in
                    guard let request = request else {
                        print("HttpServer: error -- No Request")
                        return nil
                    }
                    print("HttpServer: PATH -- \(request.path)")
                    if self.isDeviceQuery(request: request) {
                        return try self.handleDeviceQuery(request: request)
                    } else if self.isScpdQuery(request: request) {
                        return try self.handleScpdQuery(request: request)
                    } else if self.isControlQuery(request: request) {
                        return try self.handleControlQuery(request: request)
                    } else if self.isEventQuery(request: request) {
                        return try self.handleEventQuery(request: request)
                    } else {
                        print("HttpServer: unknown request -- \(request.path)")
                    }
                    return nil
                }
                try self.httpServer!.run()
            } catch let error{
                print("HttpServer: error -- \(error)")
            }
            self.httpServer = nil
        }
    }

    func isDeviceQuery(request: HttpRequest) -> Bool {
        return request.path.hasSuffix("device.xml")
    }

    func isScpdQuery(request: HttpRequest) -> Bool {
        return request.path.hasSuffix("scpd.xml")
    }

    func isControlQuery(request: HttpRequest) -> Bool {
        return request.path.hasSuffix("control.xml")
    }

    func isEventQuery(request: HttpRequest) -> Bool {
        return request.path.hasSuffix("event.xml")
    }

    func handleDeviceQuery(request: HttpRequest) throws -> HttpResponse? {
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
    }

    func handleScpdQuery(request: HttpRequest) throws -> HttpResponse? {
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
        print("HttpServer: failed -- scpd not found")
        return nil
    }

    func handleControlQuery(request: HttpRequest) throws -> HttpResponse?{
        print("HttpServer: Action Request -- \(request.path)")
        
        guard let contentLength = request.header.contentLength else {
            print("HttpServer: error -- no content length")
            return nil
        }

        guard contentLength > 0 else {
            print("HttpServer: content length -- \(contentLength)")
            return nil
        }

        var data = Data(capacity: contentLength)
        guard try request.remoteSocket?.read(into: &data) == contentLength else {
            print("HttpServer: socket read() -- failed")
            return nil
        }

        guard let xmlString = String(data: data, encoding: .utf8) else {
            print("HttpServer: XML STRING FAILED")
            return nil
        }

        guard let soapRequest = UPnPSoapRequest.read(xmlString: xmlString) else {
            print("HttpServer: NOT SOAP REQUEST -- \(xmlString)")
            return nil
        }

        guard let handler = self.onActionRequestHandler else {
            print("HttpServer: No Handler")
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
    }

    func handleEventQuery(request: HttpRequest) throws -> HttpResponse? {
        guard let callbackUrls = request.header["CALLBACK"] else {
            print("HttpServer: no callback field")
            return nil
        }
        let urls = readCallbackUrls(text: callbackUrls)
        for (_, device) in self.devices {
            guard let service = device.getService(withEventSubUrl: request.path) else {
                continue
            }
            let subscription = UPnPEventSubscription.generate(service: service,
                                                              callbackUrls: urls)
            print("HttpServer: generated sid -- \(subscription.sid)")
            self.subscriptions[subscription.sid] = subscription
            let response = HttpResponse(code: 200, reason: "OK")
            response.header["SID"] = subscription.sid
            return response
        }
        return nil
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

    /**
     Stop UPnP Server
     */
    public func finish() {
        if let httpServer = httpServer {
            httpServer.finish()
        }
        if let ssdpReceiver = ssdpReceiver {
            ssdpReceiver.finish()
        }
    }

    /**
     On SSDP Header with address, SSDP Header
     */
    public func onSSDPHeader(address: (hostname: String, port: Int32)?, ssdpHeader: SSDPHeader?) -> [SSDPHeader]? {
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

        guard let httpServerAddress = httpServer.serverAddress else {
            return nil
        }

        guard let addr = Network.getInetAddress() else {
            return nil
        }
        let hostname = addr.hostname
        let location = "http://\(hostname):\(httpServerAddress.port)/\(udn)/device.xml"
        return location
    }

    /**
     Set Property with Service and properties
     */
    public func setProperty(service: UPnPService, properties: [String:String]) {
        let subscriptions = getEventSubscriptions(service: service)
        for subscription in subscriptions {
            let properties = UPnPEventProperties(fromDict: properties)
            sendEventProperties(subscription: subscription, properties: properties)
        }
    }

    /**
     Send Event Properties with Subscription and properties
     */
    public func sendEventProperties(subscription: UPnPEventSubscription, properties: UPnPEventProperties) {
        for url in subscription.callbackUrls {
            let data = properties.xmlDocument.data(using: .utf8)
            var fields = [KeyValuePair]()
            fields.append(KeyValuePair(key: "Content-Type", value: "text/xml"))
            fields.append(KeyValuePair(key: "SID", value: subscription.sid))
            HttpClient(url: url, method: "NOTIFY", data: data, contentType: "text/xml") {
                (data, response, error) in
                guard error == nil else {
                    print("error - \(error!)")
                    return
                }
            }.start()
        }
    }

}
