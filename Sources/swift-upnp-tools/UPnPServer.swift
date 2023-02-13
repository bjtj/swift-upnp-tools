//
// UPnPServer.swift
// 

import Foundation
import SwiftHttpServer

/**
 UPnP Server Implementation
 */
public class UPnPServer : HttpRequestHandler {

    /**
     meta os name
     - e.g.) unix/5.2
     */
    public static var META_OS_NAME: String = "\(osname())"

    /**
     meta upnp version
     - e.g.) UPnP/1.1
     */
    public static var META_UPNP_VER: String = "UPnP/1.1"

    /**
     meta app name
     - e.g.) SwiftUPnPServer/1.0
     */
    public static var META_APP_NAME: String = "SwiftUPnPServer/1.0"

    /**
     server name
     e.g.) unix/5.2 UPnP/1.1 SwiftUPnPControlpoint/1.0
     */
    public static var SERVER_NAME: String {
        get {
            return "\(META_OS_NAME) \(META_UPNP_VER) \(META_APP_NAME)"
        }
    }
    
    /**
     Component
     */
    public enum Component {
        case httpserver, ssdpreceiver
    }

    /**
     Component Status
     */
    public enum ComponentStatus {
        case started, stopped
    }

    /**
     Monitoring Handler Type
     */
    public typealias monitoringHandler = ((UPnPServer, String?, Component, ComponentStatus) -> Void)

    /**
     Action Request Handler
     */
    public typealias actionHandler = ((UPnPService, UPnPSoapRequest) throws -> OrderedProperties)
    
    /**
     Send Event Property Handler
     */
    public typealias sendPropertyHandler = ((UPnPEventSubscription, Error?) -> Void)

    /**
     Subscription Handler
     */
    public typealias subscriptionHandler = ((UPnPEventSubscription) -> Void)

    /**
     Dump http request body
     */
    public var dumpBody: Bool {
        return true
    }

    /**
     http server hostname
     */
    public var hostname: String

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
  
    var _activeDevices = [String:UPnPDevice]()
    var _devices = [String:UPnPDevice]()
    
    /**
     active device list
     */
    public var activeDevices: [UPnPDevice] {
        return _activeDevices.map {
            $1
        }
    }
    
    /**
     all devices
     */
    public var allDevices: [UPnPDevice] {
        return _devices.map {
            $1
        }
    }
    
    /**
     subscriptions
     */
    public var subscriptions = [String:UPnPEventSubscription]()

    /**
     event subscription handler
     */
    var eventSubscriptionHandler: subscriptionHandler?

    /**
     on action request handler
     */
    var actionRequestHandler: actionHandler?

    /**
     lock queue
     */
    let lockQueue = DispatchQueue(label: "com.tjapp.swiftUPnPServer.lockQueue")

    var monitorName: String?
    var monitoringHandler: monitoringHandler?
    
    var timer: DispatchSourceTimer?

    public init(httpServerBindHostname: String? = nil, httpServerBindPort: Int = 0) {
        if httpServerBindHostname == nil {
            self.hostname = Network.getInetAddress()!.hostname
        } else {
            self.hostname = httpServerBindHostname!
        }
        self.port = httpServerBindPort
    }

    deinit {
        finish()
    }

    /**
     Set Monitor
     */
    public func monitor(name: String?, handler: monitoringHandler?) {
        monitorName = name
        self.monitoringHandler = handler
    }

    func handleComponentStatus(_ component: Component, _ status: ComponentStatus) {
        self.monitoringHandler?(self, monitorName, component, status)
    }

    /**
     Register Devcie
     */
    public func registerDevice(device: UPnPDevice) {
        guard let udn = device.udn else {
            return
        }
        lockQueue.sync {
            _devices[udn] = device
        }
    }

    /**
     Unregister Device
     */
    public func unregisterDevice(device: UPnPDevice) {
        guard let udn = device.udn else {
            return
        }
        lockQueue.sync {
            _devices[udn] = nil
        }
    }

    /**
     Get Device with udn
     */
    public func getDevice(udn: String) -> UPnPDevice? {
        return _devices[udn]
    }

    /**
     Activate device with UDN
     */
    public func activate(udn: String) {
        guard let device = _devices[udn] else {
            return
        }
        activate(device: device)
    }
    
    /**
     Activate device
     */
    public func activate(device: UPnPDevice) {
        guard let udn = device.udn else {
            return
        }
        
        lockQueue.sync {
            self._activeDevices[udn] = device
        }

        self.announceDeviceAlive(device: device)
        Thread.sleep(forTimeInterval: 0.1)
        self.announceDeviceAlive(device: device)
    }
    
    
    // MARK: notify alive
    
    /**
     Announce device alive
     */
    public func announceDeviceAlive(device: UPnPDevice) {
        guard let location = getLocation(of: device) else {
            return
        }
        
        UPnPServer.announceDeviceAlive(device: device, location: location)
    }

    /**
     Announce deivce alive
     */
    public class func announceDeviceAlive(device: UPnPDevice, location: String) {

        guard let udn = device.udn else {
            return
        }
        
        guard let usn_list = device.allUsnList else {
            return
        }

        notifyAlive(usn: UPnPUsn(uuid: udn, type: "upnp:rootDevice"), location: location)
        notifyAlive(usn: UPnPUsn(uuid: udn), location: location)
        for usn in usn_list {
            notifyAlive(usn: usn, location: location)
        }
    }

    /**
     Notify alive
     */
    public class func notifyAlive(usn: UPnPUsn, location: String) {
        let properties = OrderedProperties()
        properties["HOST"] = "\(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)"
        properties["CACHE-CONTROL"] = "max-age=1800"
        properties["NTS"] = "ssdp:alive"
        properties["NT"] = usn.type.isEmpty ? usn.uuid : usn.type
        properties["USN"] = usn.description
        properties["LOCATION"] = location
        properties["SERVER"] = UPnPServer.SERVER_NAME
        SSDP.notify(properties: properties)
    }
    
    
    // MARK: notify update
    
    /**
     Announce device update
     */
    public func announceDeviceUpdate(device: UPnPDevice) {
        guard let location = getLocation(of: device) else {
            return
        }
        
        UPnPServer.announceDeviceUpdate(device: device, location: location)
    }

    /**
     Announce deivce update
     */
    public class func announceDeviceUpdate(device: UPnPDevice, location: String) {
        
        guard let udn = device.udn else {
            return
        }
        
        notifyUpdate(usn: UPnPUsn(uuid: udn, type: "upnp:rootDevice"), location: location)
    }

    /**
     Notify update
     */
    public class func notifyUpdate(usn: UPnPUsn, location: String) {
        let properties = OrderedProperties()
        properties["HOST"] = "\(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)"
        properties["NTS"] = "ssdp:update"
        properties["NT"] = usn.type.isEmpty ? usn.uuid : usn.type
        properties["USN"] = usn.description
        properties["LOCATION"] = location
        SSDP.notify(properties: properties)
    }
    

    /**
     Deactivate device with UDN
     */
    public func deactivate(udn: String) {
        guard let device = _devices[udn] else {
            return
        }
        
        deactivate(device: device)
    }
    
    /**
     Deactivate device
     */
    public func deactivate(device: UPnPDevice) {
        
        guard let udn = device.udn else {
            return
        }
        
        lockQueue.sync {
            self._activeDevices[udn] = nil
        }
        
        announceDeviceByeBye(device: device)
    }
    
    // MARK: notify byebye
    
    /**
     Announce device byebye
     */
    public func announceDeviceByeBye(device: UPnPDevice) {
        UPnPServer.announceDeviceByeBye(device: device)
    }

    /**
     Announce device byebye
     */
    public class func announceDeviceByeBye(device: UPnPDevice) {
        guard let usn_list = device.allUsnList else {
            return
        }
        guard let udn = device.udn else {
            return
        }
        
        notifyByebye(usn: UPnPUsn(uuid: udn, type: "upnp:rootDevice"))
        notifyByebye(usn: UPnPUsn(uuid: udn))
        for usn in usn_list {
            notifyByebye(usn: usn)
        }
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
     On Action Request
     */
    public func on(actionRequest handler: actionHandler?) {
        self.actionRequestHandler = handler
    }

    /**
     On Action Request
     */
    @available(*, deprecated, renamed: "on(actionRequest:)")
    public func onActionRequest(handler: actionHandler?) {
        self.actionRequestHandler = handler
    }

    /**
     Start UPnP Server
     */
    public func run() throws {
        startHttpServer()
        startSsdpReceiver()
        try startTimer()
    }

    /**
     Start HTTP Server
     */
    public func startHttpServer() {

        DispatchQueue.global(qos: .default).async {

            guard self.httpServer == nil else {
                // already started
                return
            }
            
            do {
                let server = HttpServer(hostname: self.hostname, port: self.port)
                self.httpServer = server
                server.monitor(monitorName: "server-monitor") {
                    (name, status, error) in
                    switch status {
                    case .started:
                        self.handleComponentStatus(.httpserver, .started)
                    default:
                        self.handleComponentStatus(.httpserver, .stopped)
                    }
                }
                try server.route(pattern: "/**", handler: self)
                try server.run()
            } catch let error{
                print("HttpServer::startHttpServer() error -- \(error)")
            }
            self.httpServer = nil
        }
    }


    public func onHeaderCompleted(header: HttpHeader, request: HttpRequest, response: HttpResponse) throws {
    }

    
    public func onBodyCompleted(body: Data?, request: HttpRequest, response: HttpResponse) throws {
        if isDeviceQuery(request: request) {
            try handleDeviceQuery(request: request, response: response)
            return
        } else if isScpdQuery(request: request) {
            try handleScpdQuery(request: request, response: response)
            return
        } else if isControlQuery(request: request) {
            try handleControlQuery(data: body, request: request, response: response)
            return
        } else if isEventSubQuery(request: request) {
            if request.header.firstLine.first == "SUBSCRIBE" {
                try handleEventSubQuery(request: request, response: response)
                return
            }
            if request.header.firstLine.first == "UNSUBSCRIBE" {
                try handleEventUnSubQuery(request: request, response: response)
                return
            }
        }
        response.status = .notFound
    }

    func isDeviceQuery(request: HttpRequest) -> Bool {
        return request.path.hasSuffix("device.xml")
    }

    func isScpdQuery(request: HttpRequest) -> Bool {
        var result = false
        lockQueue.sync {
            for (_, device) in self._activeDevices {
                if let _ = device.getService(withScpdUrl: request.path) {
                    result = true
                    break
                }
            }
        }
        return result
    }

    func isControlQuery(request: HttpRequest) -> Bool {
        var result = false
        lockQueue.sync {
            for (_, device) in self._activeDevices {
                if let _ = device.getService(withControlUrl: request.path) {
                    result = true
                    break
                }
            }
        }
        return result
    }

    func isEventSubQuery(request: HttpRequest) -> Bool {
        var result = false
        lockQueue.sync {
            for (_, device) in self._activeDevices {
                if let _ = device.getService(withEventSubUrl: request.path) {
                    result = true
                    break
                }
            }
        }
        return result
    }

    func handleDeviceQuery(request: HttpRequest, response: HttpResponse) throws {
        try lockQueue.sync {
            
            let tokens = request.path.split(separator: "/")
            guard tokens.isEmpty == false else {
                throw HttpServerError.custom(string: "tokens.isEmpty == false failed")
            }
            let udn = String(tokens[0])
            guard let device = _activeDevices[udn] else {
                throw HttpServerError.custom(string: "no device")
            }
            response.status = .ok
            response.contentType = "text/xml"
            response.data = device.xmlDocument.data(using: .utf8)
        }
    }

    func handleScpdQuery(request: HttpRequest, response: HttpResponse) throws {
        try lockQueue.sync {
            for (_, device) in self._activeDevices {
                if let service = device.getService(withScpdUrl: request.path) {
                    guard let scpd = service.scpd else {
                        continue
                    }
                    response.status = .ok
                    response.contentType = "text/xml"
                    response.data = scpd.xmlDocument.data(using: .utf8)
                    return
                }
            }
            throw HttpServerError.custom(string: "No service with '\(request.path)'")
        }
    }

    func handleControlQuery(data: Data?, request: HttpRequest, response: HttpResponse) throws {
        guard let data = data else {
            throw HttpServerError.illegalArgument(string: "no content")
        }

        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw HttpServerError.illegalArgument(string: "wrong xml string")
        }

        guard let soapRequest = try UPnPSoapRequest.read(xmlString: xmlString) else {
            throw HttpServerError.custom(string: "parse failed soap request")
        }

        response.header["SERVER"] = UPnPServer.SERVER_NAME

        guard let handler = self.actionRequestHandler else {
            print("HttpServer::handleControlQuery() No Handler")
            let errorResponse = UPnPSoapErrorResponse(error: .actionFailed)
            response.status = .internalServerError
            response.contentType = "text/xml; charset=\"utf-8\""
            response.data = errorResponse.xmlDocument.data(using: .utf8)
            return
        }
        
        lockQueue.sync {
            for (_, device) in self._activeDevices {
                if let service = device.getService(withControlUrl: request.path) {

                    do {
                        let properties = try handler(service, soapRequest)
                        let soapResponse = UPnPSoapResponse(serviceType: soapRequest.serviceType,
                                                            actionName: soapRequest.actionName)
                        
                        properties.fields.forEach { soapResponse[$0.key] = $0.value }
                        
                        response.status = .ok
                        response.contentType = "text/xml"
                        response.data = soapResponse.xmlDocument.data(using: .utf8)
                        return
                    } catch let error as UPnPActionError {
                        let errorResponse = UPnPSoapErrorResponse(error: error)
                        response.status = .internalServerError
                        response.contentType = "text/xml; charset=\"utf-8\""
                        response.data = errorResponse.xmlDocument.data(using: .utf8)
                        return
                    } catch {
                        let errorResponse = UPnPSoapErrorResponse(error: .actionFailed)
                        response.status = .internalServerError
                        response.contentType = "text/xml; charset=\"utf-8\""
                        response.data = errorResponse.xmlDocument.data(using: .utf8)
                        return
                    }
                }
            }

            let errorResponse = UPnPSoapErrorResponse(error: .invalidAction)
            response.status = .internalServerError
            response.contentType = "text/xml; charset=\"utf-8\""
            response.data = errorResponse.xmlDocument.data(using: .utf8)
        }
    }

    func handleEventSubQuery(request: HttpRequest, response: HttpResponse) throws {
        guard let callbackUrls = request.header["CALLBACK"] else {
            throw HttpServerError.illegalArgument(string: "No Callback Header Field")
        }
        
        if let sid = request.header["SID"], let subscription = _subscription_safe(sid) {
            subscription.renewTimeout()
            response.status = .ok
            response.header["SID"] = sid
            response.header["TIMEOUT"] = "Second-1800"
            response.header["SERVER"] = UPnPServer.SERVER_NAME
            return
        }
        
        let urls = UPnPCallbackUrl.read(text: callbackUrls)

        guard urls.isEmpty == false else {
            response.status = .custom(400, "Incompatible Header Fields")
            return
        }
        
        try lockQueue.sync {
            for (_, device) in self._activeDevices {
                guard let service = device.getService(withEventSubUrl: request.path) else {
                    continue
                }
                guard let udn = device.udn else {
                    continue
                }
                let subscription = UPnPEventSubscription.make(udn: udn, service: service, callbackUrls: urls)

                if let handler = self.eventSubscriptionHandler {
                    handler(subscription)
                }
                
                subscriptions[subscription.sid] = subscription
                
                response.status = .ok
                response.header["SID"] = subscription.sid
                response.header["TIMEOUT"] = "Second-1800"
                response.header["SERVER"] = UPnPServer.SERVER_NAME
                return
            }
            throw HttpServerError.custom(string: "no matching device")
        }
    }

    func _subscription_safe(_ sid: String) -> UPnPEventSubscription? {
        var result: UPnPEventSubscription?
        lockQueue.sync {
            result = subscriptions[sid]
        }
        return result
    }

    func handleEventUnSubQuery(request: HttpRequest, response: HttpResponse) throws {
        guard let sid = request.header["SID"] else {
            throw UPnPError.custom(string: "unsubscribe failed - no sid found in header")
        }
        lockQueue.sync {
            self.subscriptions[sid] = nil
        }
        response.status = .ok
    }

    /**
     Start SSDP Receiver
     */
    public func startSsdpReceiver() {

        DispatchQueue.global(qos: .default).async {

            guard self.ssdpReceiver == nil else {
                return
            }
            do {
                let receiver = try SSDPReceiver() {
                    (address, ssdpHeader, error) in
                    return self.onSSDPHeader(address, ssdpHeader, error)
                }
                self.ssdpReceiver = receiver
                receiver.monitor(name: "server-monitor") {
                    (name, status) in
                    switch status {
                    case .started:
                        self.handleComponentStatus(.ssdpreceiver, .started)
                    default:
                        self.handleComponentStatus(.ssdpreceiver, .stopped)
                    }
                }
                try receiver.run()
            } catch let error {
                print("UPnPServer::startSsdpReceiver() error - \(error)")
            }
            self.ssdpReceiver = nil
        }
    }
    
    func startTimer() throws {
        let queue = DispatchQueue(label: "com.tjapp.upnp.server.timer")
        timer = DispatchSource.makeTimerSource(queue: queue)
        guard let timer = timer else {
            throw UPnPError.custom(string: "Failed DispatchSource.makeTimerSource")
        }
        timer.schedule(deadline: .now(), repeating: 15.0, leeway: .seconds(0))
        timer.setEventHandler { () in
            self.lockQueue.sync {
                self.removeExpiredSubscribers()
                self.sendAllNotifyAlive()
            }
        }
        timer.resume()
    }
    
    func removeExpiredSubscribers() {
        subscriptions = subscriptions.filter {
            $1.isExpired == false
        }
    }

    func sendAllNotifyAlive() {
        allDevices.forEach {
            announceDeviceAlive(device: $0)
        }
    }
    
    func sendAllNotifyUpdates() {
        allDevices.forEach {
            announceDeviceUpdate(device: $0)
        }
    }

    /**
     Stop UPnP Server
     */
    public func finish() {
        timer?.cancel()
        httpServer?.finish()
        ssdpReceiver?.finish()
        lockQueue.sync {
            _activeDevices.removeAll()
            _devices.removeAll()
            subscriptions.removeAll()
            self.actionRequestHandler = nil
        }
    }

    /**
     On SSDP Header with address, SSDP Header
     */
    public func onSSDPHeader(_ address: (hostname: String, port: Int32)?, _ ssdpHeader: SSDPHeader?, _ error: Error?) -> [SSDPHeader]? {
        guard error == nil else {
//            error
            return nil
        }
        guard let header = ssdpHeader else {
//            something wrong
            return nil
        }
        if header.isMsearch {
            if let st = header["ST"] {
                var responses = [SSDPHeader]()
                switch st {
                case "ssdp:all":
                    lockQueue.sync {
                        for (udn, device) in self._activeDevices {
                            guard let location = getLocation(of: device) else {
                                continue
                            }
                            let rootDevice = UPnPUsn(uuid: udn, type: "upnp:rootdevice")
                            responses.append(makeMsearchResponse(from: rootDevice, location: location))
                            guard let usn_list = device.allUsnList else {
                                continue
                            }
                            responses.append(makeMsearchResponse(from: UPnPUsn(uuid: udn), location: location))
                            for usn in usn_list {
                                responses.append(makeMsearchResponse(from: usn, location: location))
                            }
                        }
                    }
                    break
                case "upnp:rootdevice":
                    lockQueue.sync {
                        for (udn, device) in self._activeDevices {
                            guard let location = getLocation(of: device) else {
                                continue
                            }
                            let usn = UPnPUsn(uuid: udn, type: st)
                            responses.append(makeMsearchResponse(from: usn, location: location))
                        }
                    }
                    break
                default:
                    lockQueue.sync {
                        for (udn, device) in self._activeDevices {
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
        header["SERVER"] = UPnPServer.SERVER_NAME
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

        let location = "http://\(httpServerAddress.hostname):\(httpServerAddress.port)/\(udn)/device.xml"
        return location
    }

    public func on(eventSubscription handler: subscriptionHandler?) {
        self.eventSubscriptionHandler = handler
    }

    /**
     Set Property with Service and properties
     */
    public func setProperty(udn: String, serviceId: String, properties: [String:String], completionHandler: sendPropertyHandler? = nil) {
        let subscriptions = getEventSubscriptions(udn: udn, serviceId: serviceId)
        for subscription in subscriptions {
            let properties = UPnPEventProperties(fromDict: properties)
            sendEventProperties(subscription: subscription, properties: properties, completionHandler: completionHandler)
        }
    }

    /**
     Get Event Subcscriptions with service
     */
    public func getEventSubscriptions(udn: String, serviceId: String) -> [UPnPEventSubscription] {
        var result = [UPnPEventSubscription]()
        lockQueue.sync {
            for (_, subscription) in subscriptions {
                if subscription.udn == udn && subscription.service?.serviceId == serviceId {
                    result.append(subscription)
                }
            }
        }
        return result
    }

    /**
     Send Event Properties with Subscription and properties
     */
    public func sendEventProperties(subscription: UPnPEventSubscription, properties: UPnPEventProperties, completionHandler: sendPropertyHandler? = nil) {
        for url in subscription.callbackUrls {
            guard let data = properties.xmlDocument.data(using: .utf8) else {
                continue
            }
            var fields = [KeyValuePair]()
            fields.append(KeyValuePair(key: "USER-AGENT", value: UPnPServer.SERVER_NAME))
            fields.append(KeyValuePair(key: "NT", value: "upnp:event"))
            fields.append(KeyValuePair(key: "NTS", value: "upnp:propchange"))
            fields.append(KeyValuePair(key: "SID", value: subscription.sid))
            HttpClient(url: url, method: "NOTIFY", data: data, contentType: "text/xml", fields: fields) {
                (data, response, error) in
                guard error == nil else {
                    completionHandler?(subscription, error)
                    self.handleSendEvent(subscription, error)
                    return
                }
                guard getStatusCodeRange(response: response) == .success else {
                    let err = HttpError.notSuccess(code: getStatusCode(response: response, defaultValue: 0))
                    completionHandler?(subscription, err)
                    self.handleSendEvent(subscription, err)
                    return
                }
            }.start()
        }
    }
    
    func handleSendEvent(_ subscription: UPnPEventSubscription, _ error: Error?) {
        guard error == nil else {
            lockQueue.sync {
                self.subscriptions[subscription.sid] = nil
            }
            return
        }
    }

}
