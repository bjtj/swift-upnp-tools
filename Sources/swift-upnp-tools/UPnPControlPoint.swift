//
// UPnPControlPoint.swift
// 

import Foundation
import SwiftHttpServer

/**
 UPnP ControlPoint Delegate
 */
public protocol UPnPControlPointDelegate {
    
    /**
     Handle ssdp header
     */
    @discardableResult func ssdpHeader(_ address: (String, Int32)?, _ ssdpHeader: SSDPHeader?, _ error: Error?) -> [SSDPHeader]?
    
    /**
     On Device Added
     */
    func onDeviceAdded(device: UPnPDevice)
    /**
     On Device Removed
     */
    func onDeviceRemoved(device: UPnPDevice)
    
    /**
     Handle event property
     */
    func eventPropperties(subscriber: UPnPEventSubscriber?, properties: UPnPEventProperties?, error: Error?) throws
    
    /**
     subscription changed
     */
    func subscription(added subscriber: UPnPEventSubscriber)
    
    /**
     subscription changed
     */
    func subscription(removed subscriber: UPnPEventSubscriber)
}


/**
 UPnP Control Point Implementation
 */
public class UPnPControlPoint : UPnPDeviceBuilderDelegate, HttpRequestHandler {

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
     - e.g.) SwiftUPnPControlpoint/1.0
     */
    public static var META_APP_NAME: String = "SwiftUPnPControlpoint/1.0"

    /**
     user agent
     e.g.) unix/5.2 UPnP/1.1 SwiftUPnPControlpoint/1.0
     */
    public static var USER_AGENT: String {
        get {
            return "\(META_OS_NAME) \(META_UPNP_VER) \(META_APP_NAME)"
        }
    }

    /**
     
     */
    public enum SuspendBehavior {
        case noop
        case unsubscribe
        case unsubscribeAndRemove
    }

    /**
     
     */
    public enum ResumeBehavior {
        case noop
        case removeExpired
        case resubscribe
    }

    /**
     ControlPoint Components
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

    /*
     monitor handler
     */
    public typealias monitoringHandler = ((UPnPControlPoint, String?, Component, ComponentStatus) -> Void)

    var monitorName: String?
    var monitoringHandler: monitoringHandler?

    /**
     set dump body flag for http server
     */
    public var dumpBody: Bool {
        return true
    }

    /**
     scpdHandler
     - Parameter device
     - Parameter service
     - Parameter scpd
     - Parameter error
     */
    public typealias scpdHandler = ((UPnPDevice?, UPnPService?, UPnPScpd?, Error?) -> Void)

    /**
     is running
     */
    public var running: Bool {
        get {
            return _running
        }
    }
    var _running: Bool = false

    /**
     is suspended
     */
    public var suspended: Bool {
        get {
            return _suspended
        }
    }
    var _suspended: Bool = false
    

    /**
     http server bind hostname
     */
    public var hostname: String?

    /**
     http server bind port
     */
    public var port: Int

    /**
     http server
     */
    public var httpServer : HttpServer?

    /**
     ssdp receiver
     */
    public var ssdpReceiver : SSDPReceiver?

    /**
     presentable devices
     */
    public var presentableDevices: [String:UPnPDevice] {
        var result: [String:UPnPDevice]?
        lockQueue.sync {
            result = _devices.filter { [.incompleted, .completed].contains($1.status) }
        }
        return result ?? [String:UPnPDevice]()
    }
    var _devices = [String:UPnPDevice]()

    /**
     devices
     @deprecated use `presentableDevices` instead
     */
    @available(*, deprecated, renamed: "presentableDevices")
    public var devices: [String:UPnPDevice] {
        return _devices
    }

    var subscribeHandler: UPnPEventSubscriber.subscribeCompletionHandler?
    var renewSubscribeHandler: UPnPEventSubscriber.renewSubscribeCompletionHandler?
    var unsubscribeHandler: UPnPEventSubscriber.unsubscribeCompletionHandler?

    /**
     delegate
     */
    public var delegate: UPnPControlPointDelegate?
    
    class Subscribers {
        var list = [UPnPEventSubscriber]()
        
        func append(_ subscriber: UPnPEventSubscriber, handler: ((UPnPEventSubscriber) -> Void)) {
            list.append(subscriber)
            handler(subscriber)
        }
        
        func remove(sid: String, handler: ((UPnPEventSubscriber) -> Void)? = nil) {
            list.removeAll(where: { if $0.sid == sid { handler?($0); return true} else { return false } })
        }
        
        func removeAll(_ handler: ((UPnPEventSubscriber) -> Void)? = nil) {
            list.removeAll(where: { handler?($0); return true })
        }
        
        func removeExpired(handler: ((UPnPEventSubscriber) -> Void)) {
            list = list.filter { if $0.isExpired { handler($0); return false } else { return true } }
        }

        func forEach(_ handler: ((UPnPEventSubscriber) -> Void)) {
            list.forEach(handler)
        }
        
        func unsubscribeAll(completionHandler: UPnPEventSubscriber.unsubscribeCompletionHandler? = nil) {
            list.forEach {
                $0.unsubscribe(completionHandler: completionHandler)
            }
        }
        
        func renew(where condition: (UPnPEventSubscriber) -> Bool, completionHandler handler: UPnPEventSubscriber.renewSubscribeCompletionHandler?) {
            list.forEach {
                if condition($0) {
                    $0.renewSubscribe(completionHandler: handler)
                }
            }
        }
        
        subscript(sid: String) -> UPnPEventSubscriber? {
            for subscriber in list {
                guard let subscriber_sid = subscriber.sid, subscriber_sid == sid else {
                    continue
                }
                return subscriber
            }
            return nil
        }
        
        func subscribers(udn: String) -> [UPnPEventSubscriber] {
            return list.filter { $0.udn == udn }
        }
        
        func subscribers(udn: String, serviceId: String) -> [UPnPEventSubscriber] {
            return list.filter { $0.udn == udn && $0.service.serviceId == serviceId }
        }
        
        func subscribers(serviceId: String) -> [UPnPEventSubscriber] {
            return list.filter { $0.service.serviceId == serviceId }
        }
    }

    /**
     event subscribers
     */
    var eventSubscribers = Subscribers()
    
    /**
     event property handlers
     */
    var notificationHandlers = [UPnPEventSubscriber.eventNotificationHandler]()

    /**
     on device added handlers
     */
    var onDeviceAddedHandlers = [(UPnPDevice) -> Void]()

    /**
     on device removed handlers
     */
    var onDeviceRemovedHandlers = [(UPnPDevice) -> Void]()

    /**
     on scpd handlers
     */
    var onScpdHandlers = [scpdHandler]()

    /**
     timer
     */
    var timer: DispatchSourceTimer?

    /**
     lock queue
     */
    let lockQueue = DispatchQueue(label: "com.tjapp.swiftUPnPControlPoint.lockQueue")
    
    public init(httpServerBindHostname: String? = nil, httpServerBindPort: Int = 0, delegate: UPnPControlPointDelegate? = nil) {
        if httpServerBindHostname == nil {
            self.hostname = Network.getInetAddress()?.hostname
        } else {
            self.hostname = httpServerBindHostname
        }
        self.port = httpServerBindPort
        self.delegate = delegate
    }

    deinit {
        finish()
    }

    /**
     on subscribe
     */
    public func on(subscribe handler: UPnPEventSubscriber.subscribeCompletionHandler?) {
        subscribeHandler = handler
    }

    /**
     on renew subscribe
     */
    public func on(renewSubscribe handler: UPnPEventSubscriber.renewSubscribeCompletionHandler?) {
        renewSubscribeHandler = handler
    }

    /**
     on unsubscribe
     */
    public func on(unsubscribe handler: UPnPEventSubscriber.unsubscribeCompletionHandler?) {
        unsubscribeHandler = handler
    }

    /**
     on scpd
     */
    public func on(scpd handler: scpdHandler?) {
        guard let handler = handler else {
            return
        }
        onScpdHandlers.append(handler)
    }

    /**
     on event properties
     */
    public func on(eventProperties handler: UPnPEventSubscriber.eventNotificationHandler?) {
        guard let handler = handler else {
            return
        }
        self.notificationHandlers.append(handler)
    }

    /**
     on add device
     */
    public func on(addDevice handler: ((UPnPDevice) -> Void)?) {
        guard let handler = handler else {
            return
        }
        onDeviceAddedHandlers.append(handler)
    }

    /**
     on remove device
     */
    public func on(removeDevice handler: ((UPnPDevice) -> Void)?) {
        guard let handler = handler else {
            return
        }
        onDeviceRemovedHandlers.append(handler)
    }

    /**
     set monitoring handler
     */
    public func monitor(name: String, handler: monitoringHandler?) {
        monitorName = name
        self.monitoringHandler = handler
    }

    /**
     Start UPnP Control Point
     */
    public func run() throws {

        if _running {
            print("UPnPControlPoint::run() - aready running")
            return
        }

        _running = true
        _suspended = false
        startHttpServer()
        startSsdpReceiver()
        try startTimer()
    }

    /**
     Stop UPnP Control Point
     */
    public func finish() {
        timer?.cancel()
        httpServer?.finish()
        ssdpReceiver?.finish()

        _devices.removeAll()
        delegate = nil
        eventSubscribers.unsubscribeAll(completionHandler: unsubscribeHandler)
        eventSubscribers.removeAll(subscription(removed:))
        self.notificationHandlers.removeAll()
        onDeviceAddedHandlers.removeAll()
        onDeviceRemovedHandlers.removeAll()
        onScpdHandlers.removeAll()

        _running = false
    }

    /**
     suspend
     */
    public func suspend(_ behavior: SuspendBehavior = .unsubscribe) {

        if _suspended {
            // already suspended
            return
        }
        _suspended = true
        timer?.cancel()
        httpServer?.finish()
        ssdpReceiver?.finish()

        switch behavior {
        case .unsubscribe:
            eventSubscribers.unsubscribeAll(completionHandler: unsubscribeHandler)
            break
        case .unsubscribeAndRemove:
            eventSubscribers.unsubscribeAll(completionHandler: unsubscribeHandler)
            eventSubscribers.removeAll()
            break
        default:
            break
        }
    }

    /**
     resume
     */
    public func resume(_ behavior: ResumeBehavior = .resubscribe) throws {

        if !_suspended || !_running {
            // already suspended or not running
            return
        }

        if behavior == .removeExpired {
            lockQueue.sync {
                removeExpiredSubscriber()
                removeExpiredDevices()
            }
        }
        
        _suspended = false
        startHttpServer {
            (httpServer, error) in

            if behavior == .resubscribe {
                self.eventSubscribers.forEach {
                    do {
                        try self.subscribe(udn: $0.udn, service: $0.service, notificationHandler: $0.notificationHandler)
                    } catch {
                        // 
                    }
                }
            }
        }
        startSsdpReceiver()
        try startTimer()
    }

    /**
     Get device with UDN
     */
    public func getDevice(udn: String) -> UPnPDevice? {
        return _devices[udn]
    }

    /**
     add notification handler
     */
    @available(*, deprecated, renamed: "on(eventProperties:)")
    public func addNotificationHandler(notificationHandler: UPnPEventSubscriber.eventNotificationHandler?) {
        guard let notificationHandler = notificationHandler else {
            return
        }
        self.notificationHandlers.append(notificationHandler)
    }

    /**
     Start HTTP Server
     */
    public func startHttpServer(readyHandler: ((HttpServer, Error?) -> Void)? = nil) {

        guard httpServer == nil else {
            print("UPnPControlPoint::startHttpServer() already started")
            // already started
            return
        }
        
        DispatchQueue.global(qos: .default).async {

            do {
                let httpServer = HttpServer(hostname: self.hostname, port: self.port)
                self.httpServer = httpServer
                httpServer.monitor(monitorName: "cp-httpserver-monitor") {
                    (name, status, error) in
                    switch status {
                    case .started:
                        self.handleComponentStatus(.httpserver, .started)
                    default:
                        self.handleComponentStatus(.httpserver, .stopped)
                    }
                }
                try httpServer.route(pattern: "/**", handler: self)
                try httpServer.run(readyHandler: readyHandler)
            } catch let error{
                print("UPnPControlPoint::startHttpServer() error - error - \(error)")
            }
            self.httpServer = nil
        }
    }

    /**
     when http request header completed
     */
    public func onHeaderCompleted(header: HttpHeader, request: HttpRequest, response: HttpResponse) throws {
    }

    /**
     when http request body completed
     */
    public func onBodyCompleted(body: Data?, request: HttpRequest, response: HttpResponse) throws {

        guard request.method.caseInsensitiveCompare("NOTIFY") == .orderedSame else {
            let err = UPnPError.custom(string: "Not Supported Method - '\(request.method)'")
            try eventProperties(subscriber: nil, properties: nil, error: err)
            throw err
        }

        guard let data = body else {
            let err = HttpServerError.illegalArgument(string: "No Content")
            try eventProperties(subscriber: nil, properties: nil, error: err)
            throw err
        }

        guard let xmlString = String(data: data, encoding: .utf8) else {
            let err = HttpServerError.illegalArgument(string: "Wrong XML String")
            try eventProperties(subscriber: nil, properties: nil, error: err)
            throw err
        }
        
        guard let properties = try UPnPEventProperties.read(xmlString: xmlString) else {
            let err = HttpServerError.custom(string: "Parse Failed Event Properties")
            try eventProperties(subscriber: nil, properties: nil, error: err)
            throw err
        }

        do {
            guard let sid = request.header["sid"] else {
                throw HttpServerError.illegalArgument(string: "No SID")
            }
            
            guard let subscriber = self.getEventSubscriber(sid: sid) else {
                throw HttpServerError.illegalArgument(string: "No subscbier found with SID: '\(sid)'")
            }
            
            try self.eventProperties(subscriber: subscriber, properties: properties, error: nil)
            response.status = .ok
            
        } catch {
            try self.eventProperties(subscriber: nil, properties: properties, error: error)
            throw error
        }
    }
    
    func eventProperties(subscriber: UPnPEventSubscriber?, properties: UPnPEventProperties?, error: Error?) throws {
        
        try delegate?.eventPropperties(subscriber: subscriber, properties: properties, error: error)
        
        for notificationHandler in self.notificationHandlers {
            try notificationHandler(subscriber, properties, error)
        }
        try  subscriber?.handleNotification(properties: properties, error: error)
    }

    /**
     Start SSDP Receiver
     */
    public func startSsdpReceiver() {

        guard ssdpReceiver == nil else {
            print("UPnPControlPoint::startSsdpReceiver() already started")
            return
        }

        DispatchQueue.global(qos: .default).async {
            do {
                
                let receiver = try SSDPReceiver(handler: self.ssdpHeader)
                
                self.ssdpReceiver = receiver
                receiver.monitor(name: "cp-ssdpreceiver") {
                    (name, status) in
                    switch status {
                    case .started:
                        self.handleComponentStatus(.ssdpreceiver, .started)
                    default:
                        self.handleComponentStatus(.ssdpreceiver, .stopped)
                        break
                    }
                }
                try receiver.run()
            } catch let error {
                print("UPnPControlPoint::startSsdpReceiver() error - error - \(error)")
            }
            self.ssdpReceiver = nil
        }
    }

    func handleComponentStatus(_ component: Component, _ status: ComponentStatus) {
        self.monitoringHandler?(self, monitorName, component, status)
    }

    func startTimer() throws {
        let queue = DispatchQueue(label: "com.tjapp.upnp.timer")
        timer = DispatchSource.makeTimerSource(queue: queue)
        guard let timer = timer else {
            throw UPnPError.custom(string: "Failed DispatchSource.makeTimerSource")
        }
        let interval = 10.0
        timer.schedule(deadline: (.now() + .seconds(Int(interval))), repeating: interval, leeway: .seconds(0))
        timer.setEventHandler { () in
            self.lockQueue.sync {

                self.removeExpiredSubscriber()
                self.removeExpiredDevices()

                self.eventSubscribers.renew(where: {
                    subscriber in
                    return subscriber.duration > 30
                }) {
                    subscriber, error in

                    self.renewSubscribeHandler?(subscriber, error)
                    
                    guard error == nil else {
                        if let sid = subscriber?.sid {
                            self.eventSubscribers.remove(sid: sid, handler: self.subscription(removed:))
                        }
                        return
                    }
                }
            }
        }
        timer.resume()
    }
    
    func removeExpiredDevices() {
        // TODO: on device removed
        var list = [UPnPDevice]()
        _devices = _devices.filter {
            if $1.isExpired {
                list.append($1)
            }
            return $1.isExpired == false
        }
        list.forEach {
            self.unsubscribe(forDevice: $0).forEach {
                sid in
                self.eventSubscribers.remove(sid: sid, handler: subscription(removed:))
            }
            self.device(removed: $0)
        }
    }

    func removeExpiredSubscriber() {
        // TODO: on event subscription removed
        eventSubscribers.removeExpired(handler: subscription(removed:))
    }

    /**
     Send M-SEARCH with ST (Service Type) and MX (Max)
     */
    public func sendMsearch(st: String, mx: Int = 3, ssdpHandler: SSDPReceiver.ssdpHandler? = nil, completionHandler: (() -> Void)? = nil) {

        DispatchQueue.global(qos: .default).async {
            SSDP.sendMsearch(st: st, mx: mx, userAgent: UPnPControlPoint.USER_AGENT) {
                (address, ssdpHeader, error) in
                self.ssdpHeader(address, ssdpHeader, error)
                let _ = ssdpHandler?(address, ssdpHeader, error)
                return nil
            }
            
            completionHandler?()
        }
    }

    @discardableResult func ssdpHeader(_ address: (String, Int32)?, _ ssdpHeader: SSDPHeader?, _ error: Error?) -> [SSDPHeader]? {
        
        defer {
            let _ = delegate?.ssdpHeader(address, ssdpHeader, error)
        }
        
        guard error == nil else {
//            error
            return nil
        }
        
        guard let header = ssdpHeader else {
//            something wrong
            return nil
        }
        
        if header.isNotify {
            guard let nts = header.nts else {
                return nil
            }
            switch nts {
            case .alive:
                guard let usn = header.usn else {
                    break
                }
                if let device = self._devices[usn.uuid] {
                    device.renewTimeout()
                } else if let location = header["LOCATION"] {
                    if let url = URL(string: location) {
                        let device = UPnPDevice(timeout: 15)
                        device.status = .recognized
                        lockQueue.sync {
                            _devices[usn.uuid] = device
                        }
                        buildDevice(url: url)
                    }
                }
                break
            case .byebye:
                if let usn = header.usn {
                    lockQueue.sync {
                        self.removeDevice(udn: usn.uuid)
                    }
                }
                break
            case .update:
                if let usn = header.usn {
                    if let device = self._devices[usn.uuid] {
                        device.renewTimeout()
                    }
                }
                break
            }
        } else if header.isHttpResponse {
            guard let usn = header.usn else {
                return nil
            }
            if let device = self._devices[usn.uuid] {
                device.renewTimeout()
            } else if let location = header["LOCATION"] {
                if let url = URL(string: location) {
                    _devices[usn.uuid] = UPnPDevice(timeout: 15)
                    buildDevice(url: url)
                }
            }
        }
        return nil
    }

    func buildDevice(url: URL) {
        UPnPDeviceBuilder(delegate: self) {
            (device, service, scpd, error) in 
            for handler in self.onScpdHandlers {
                handler(device, service, scpd, error)
            }
            guard let device = device, let service = service else {
                return
            }
            self.lockQueue.sync {
                if service.status == .failed {
                    device.buildingServiceErrorCount += 1
                }
                device.buildingServiceCount -= 1
                if device.buildingServiceCount <= 0 {
                    device.status = device.buildingServiceErrorCount == 0 ? .completed : .incompleted
                }
            }
        }.build(url: url)
    }

    /**
     On Device Build with URL and Device
     */
    public func onDeviceBuild(url: URL?, device: UPnPDevice?) {
        guard let device = device else {
            return
        }
        addDevice(device: device)
    }

    /**
     On Device Build Error
     */
    public func onDeviceBuildError(error: String?) {
        print("[UPnPControlPoint] Device Build Error - \(error ?? "nil")")
    }

    /**
     Add Handler: On Device Added
     */
    @available(*, deprecated, renamed: "on(addDevice:)")
    public func onDeviceAdded(handler: ((UPnPDevice) -> Void)?) {
        guard let handler = handler else {
            return
        }
        onDeviceAddedHandlers.append(handler)
    }

    /**
     Add Handler: On Device Removed
     */
    @available(*, deprecated, renamed: "on(removeDevice:)")
    public func onDeviceRemoved(handler: ((UPnPDevice) -> Void)?) {
        guard let handler = handler else {
            return
        }
        onDeviceRemovedHandlers.append(handler)
    }

    /**
     Add Handler: On Scpd
     */
    @available(*, deprecated, renamed: "on(scpd:)")
    func onScpd(handler: (scpdHandler)?) {
        guard let handler = handler else {
            return
        }
        onScpdHandlers.append(handler)
    }

    /**
     Add device with Device
     */
    public func addDevice(device: UPnPDevice) {
        guard let udn = device.udn else {
            return
        }
        lockQueue.sync {
            self._devices[udn] = device
            self.device(added: device)
        }
    }

    func device(added device: UPnPDevice)  {
        delegate?.onDeviceAdded(device: device)
        for handler in onDeviceAddedHandlers {
            handler(device)
        }
    }

    /**
     Remove Device with UDN
     */
    public func removeDevice(udn: String) {
        guard let device = _devices[udn] else {
            return
        }
        self.unsubscribe(forDevice: device).forEach {
            let sid = $0
            lockQueue.sync {
                self.eventSubscribers.remove(sid: sid, handler: subscription(removed:))
            }
        }
        self.device(removed: device)

        _devices[udn] = nil
    }

    func device(removed device: UPnPDevice) {
        delegate?.onDeviceRemoved(device: device)
        for handler in onDeviceRemovedHandlers {
            handler(device)
        }
    }

    @discardableResult func unsubscribe(forDevice device: UPnPDevice) -> [String] {
        var sids = [String]()
        if let udn = device.udn {
            self.getEventSubscribers(forUdn: udn).forEach {
                if let sid = $0.sid {
                    sids.append(sid)
                }
                $0.unsubscribe {
                    subscriber, error in
                    self.unsubscribeHandler?(subscriber, error)
                }
            }
        }
        return sids
    }

    /**
     Invoek with Service and actionRequest
     */
    public func invoke(service: UPnPService, actionRequest: UPnPActionRequest, completionHandler: (UPnPActionInvoke.invokeCompletionHandler)?) {
        return self.invoke(service: service, actionName: actionRequest.actionName, fields: actionRequest.fields, completionHandler: completionHandler);
    }

    /**
     Invoke with Service and action, properties, completionHandler (Optional)
     */
    public func invoke(service: UPnPService, actionName: String, fields: OrderedProperties, completionHandler: (UPnPActionInvoke.invokeCompletionHandler)?) {
        guard let serviceType = service.serviceType else {
            print("UPnPControlPoint::invoke() error - no service type")
            return
        }
        let soapRequest = UPnPSoapRequest(serviceType: serviceType, actionName: actionName)
        for field in fields.fields {
            soapRequest[field.key] = field.value
        }
        guard let controlUrl = service.controlUrl, let device = service.device else {
            print("UPnPControlPoint::invoke() error - no control url or no device")
            return
        }
        guard let url = URL(string: controlUrl, relativeTo: device.rootDevice.baseUrl) else {
            print("UPnPControlPoint::invoke() error - url failed")
            return
        }
        UPnPActionInvoke(url: url, soapRequest: soapRequest, userAgent: UPnPControlPoint.USER_AGENT, completionHandler: completionHandler).invoke()
    }

    /**
     Subscribe with service
     */
    @discardableResult public func subscribe(udn: String, service: UPnPService, notificationHandler: UPnPEventSubscriber.eventNotificationHandler? = nil, completionHandler: UPnPEventSubscriber.subscribeCompletionHandler? = nil) throws -> UPnPEventSubscriber? {
        guard let callbackUrls = makeCallbackUrl(udn: udn, service: service) else {
            throw UPnPError.custom(string: "UPnPControlPoint::subscribe() error - makeCallbackUrl failed")
        }
        guard let subscriber = UPnPEventSubscriber(udn: udn, service: service, callbackUrls: [callbackUrls], notificationHandler: notificationHandler) else {
            throw UPnPError.custom(string: "UPnPControlPoint::subscribe() error - UPnPEventSubscriber initializer failed")
        }
        subscriber.subscribe {
            (subscriber, error) in

            guard error == nil else {
                completionHandler?(subscriber, error)
                self.subscribeHandler?(subscriber, error)
                return
            }
            guard let subs = subscriber else {
                let err = UPnPError.custom(string: "no subscriber")
                completionHandler?(subscriber, err)
                self.subscribeHandler?(subscriber, err)
                return
            }
            
            completionHandler?(subs, nil)
            self.subscribeHandler?(subs, nil)
            
            self.lockQueue.sync {
                self.eventSubscribers.append(subs, handler: self.subscription(added:))
            }
        }
        return subscriber
    }

    /**
     unsubscribe event with sid
     */
    public func unsubscribe(sid: String, completionHandler: UPnPEventSubscriber.unsubscribeCompletionHandler? = nil) -> Void {
        guard let subscriber = self.getEventSubscriber(sid: sid) else {
            print("UPnPControlPoint::unsubscribe() error - event subscriber not found (sid: '\(sid)')")
            return
        }
        unsubscribe(subscriber: subscriber) {
            subscriber, error in
            completionHandler?(subscriber, error)
            self.unsubscribeHandler?(subscriber, error)
        }
    }

    /**
     unsubscribe event with subscriber
     */
    public func unsubscribe(subscriber: UPnPEventSubscriber, completionHandler: UPnPEventSubscriber.unsubscribeCompletionHandler? = nil) {
        subscriber.unsubscribe(completionHandler: completionHandler)
        lockQueue.sync {
            if let sid = subscriber.sid {
                self.eventSubscribers.remove(sid: sid, handler: subscription(removed:))
            }
        }
    }
    
    func subscription(added subscriber: UPnPEventSubscriber) {
        delegate?.subscription(added: subscriber)
    }
    
    func subscription(removed subscriber: UPnPEventSubscriber) {
        delegate?.subscription(removed: subscriber)
    }

    /**
     Get Event Subscriber with sid (subscription id)
     */
    public func getEventSubscriber(sid: String) -> UPnPEventSubscriber? {
        return eventSubscribers[sid]
    }

    /**
     Get Event Subscribers for UDN
     */
    public func getEventSubscribers(forUdn udn: String) -> [UPnPEventSubscriber] {
        return eventSubscribers.subscribers(udn: udn)
    }
    
    /**
     Get Event Subscribers with service
     */
    public func getEventSubscribers(service: UPnPService) -> [UPnPEventSubscriber]? {
        guard let udn = service.device?.rootDevice.udn else {
            return nil
        }
        
        guard let serviceId = service.serviceId else {
            return nil
        }
        
        return getEventSubscribers(forUdn: udn, forServiceId: serviceId)
    }

    /**
     Get Event Subscribers for UDN and Service Id
     */
    public func getEventSubscribers(forUdn udn: String, forServiceId serviceId: String) -> [UPnPEventSubscriber] {
        return eventSubscribers.subscribers(udn: udn, serviceId: serviceId)
    }

    /**
     Get Event Subscribers for Service Id
     */
    public func getEventSubscribers(forServiceId serviceId: String) -> [UPnPEventSubscriber] {
        return eventSubscribers.subscribers(serviceId: serviceId)
    }

    func makeCallbackUrl(udn: String, service: UPnPService) -> URL? {
        guard let httpServer = self.httpServer else {
            return nil
        }
        guard let httpServerAddress = httpServer.serverAddress else {
            return nil
        }
        guard let addr = Network.getInetAddress() else {
            return nil
        }
        let hostname = addr.hostname
        return UPnPCallbackUrl.make(hostname: hostname, port: httpServerAddress.port, udn: udn, serviceId: service.serviceId ?? "nil")
    }
}
