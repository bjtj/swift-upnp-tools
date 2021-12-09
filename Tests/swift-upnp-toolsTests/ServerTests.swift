//
// ServerTests.swift
// 

import XCTest
@testable import SwiftUpnpTools
import SwiftHttpServer

/**
 ServerTests
 */
final class ServerTests: XCTestCase {

    /**
     UPnP Sever for test
     */
    static var upnpServer: UPnPServer?
    static var receiver: SSDPReceiver?

    /**
     set up
     */
    override class func setUp() {
        super.setUp()

        print("-- SET UP --")

        DispatchQueue.global(qos: .background).async {
            startReceiver()
        }
        
        upnpServer = startServer()
        
        sleep(1)

        print("-- SET UP :: DONE --")
    }

    /**
     start server
     */
    class func startServer() -> UPnPServer {
        let server = UPnPServer(httpServerBindPort: 0)
        server.run()

        registerDevice(server: server)
        
        return server
    }

    /**
     register device
     */
    class func registerDevice(server: UPnPServer) {
        guard let device = UPnPDevice.read(xmlString: ServerTests.deviceDescription_DimmableLight) else {
            XCTFail("UPnPDevice read failed")
            return
        }

        guard let service = device.getService(type: "urn:schemas-upnp-org:service:SwitchPower:1") else {
            XCTFail("No Service (urn:schemas-upnp-org:service:SwitchPower:1)")
            return
        }
        service.scpd = UPnPScpd.read(xmlString: ServerTests.scpd_SwitchPower)

        XCTAssertNotNil(service.scpd)
        
        server.registerDevice(device: device)
    }

    /**
     teardown
     */
    override class func tearDown() {
        print("-- TEAR DOWN --")
        super.tearDown()
        ServerTests.upnpServer?.finish()
        receiver?.finish()
        print("-- TEAR DOWN :: DONE --")
        sleep(1)
    }

    /**
     start receiver
     */
    class func startReceiver() {
        do {
            receiver = try SSDPReceiver() {
                (address, ssdpHeader) in
                if let ssdpHeader = ssdpHeader {
                    if let address = address {
                        print("[SSDP] from -- \(address.hostname):\(address.port) / " +
                                "\(ssdpHeader.nts?.rawValue ?? "(NO NTS)")")
                    }
                }
                return nil
            }
            try receiver?.run()
        } catch let error {
            print(error)
        }
        print("-- Receiver Done --")
    }

    /**
     test notify
     */
    func testNotify() {
        guard let device = UPnPDevice.read(xmlString: ServerTests.deviceDescription_DimmableLight) else {
            return
        }
        guard let addr = Network.getInetAddress() else {
            XCTAssert(false)
            return
        }
        UPnPServer.activate(device: device, location: "http://\(addr.hostname)/dummy")
        UPnPServer.deactivate(device: device)
    }

    /**
     test server
     */
    func testServer() {

        guard let server = ServerTests.upnpServer else {
            XCTFail("UPnPServer is not ready")
            return
        }

        let device = server.getDevice(udn: "e399855c-7ecb-1fff-8000-000000000000")
        XCTAssertNotNil(device)

        // -------------------------------------------

        server.onActionRequest {
            (service, soapRequest) in
            let properties = OrderedProperties()
            properties["GetLoadlevelTarget"] = "10"
            return properties
        }

        var called = false

        let actionRequest = UPnPActionRequest(actionName: "GetLoadLevelTarget")
        helperControlPointInvokeAction(st: "ssdp:all",
                                       serviceType: "urn:schemas-upnp-org:service:SwitchPower:1",
                                       actionRequest: actionRequest)
        {
            (soapResponse, error) in

            called = true
            
            XCTAssertNil(error)
            if let soapResponse = soapResponse {
                print("[ACTION INVOKE] soapResponse:\n\(soapResponse.description)")
            }
            XCTAssertEqual(soapResponse?["GetLoadlevelTarget"], "10")
        }

        // -------------------------------------------

        let service = device!.getService(type: "urn:schemas-upnp-org:service:SwitchPower:1")
        XCTAssertNotNil(service)
        XCTAssertNotNil(device!.udn)
        helperEventSubscribe(st: "ssdp:all", serviceType: "urn:schemas-upnp-org:service:SwitchPower:1", server: server, udn: device!.udn!, service: service!, properties: ["GetLoadlevelTarget" : "12"])

        
        helperEventSubscribeAndUnsubscribe(st: "ssdp:all", serviceType: "urn:schemas-upnp-org:service:SwitchPower:1", server: server, udn: device!.udn!, service: service!, properties: ["GetLoadlevelTarget" : "321"])
        

        sleep(1)


        // -------------------------------------------

        XCTAssertTrue(called)
    }

    /**
     helper control point invoke action
     */
    func helperControlPointInvokeAction(st: String,
                                        serviceType: String,
                                        actionRequest: UPnPActionRequest,
                                        handler: (UPnPActionInvoke.invokeCompletionHandler)?)
    {
        let cp = UPnPControlPoint()

        var handledService = [UPnPService]()

        cp.onScpd {
            (device, service, scpd, error) in

            guard error == nil else {
                // error
                return
            }

            guard let service = service else {
                // error
                return
            }

            guard service.serviceType == serviceType else {
                // not expected service
                return
            }

            cp.invoke(service: service, actionRequest: actionRequest, completionHandler: handler)

            handledService.append(service)
        }

        do {
            try cp.run()
            sleep(2)
        } catch let e {
            XCTFail("cp.run() failed \(e)")
            return
        }

        guard let httpServer = cp.httpServer else {
            XCTFail("cp.httpServer is nil")
            return
        }
        XCTAssertTrue(httpServer.running)

        guard let ssdpReceiver = cp.ssdpReceiver else {
            XCTFail("cp.ssdpReceiver is nil")
            return
        }
        XCTAssertTrue(ssdpReceiver.running)

        cp.sendMsearch(st: st, mx: 3) {
            (address, header) in
            guard let header = header else {
                return
            }
            print(header.description)
        }

        sleep(3)

        XCTAssertFalse(handledService.isEmpty)

        cp.finish()

        usleep(500 * 1000)
        XCTAssertFalse(cp.running)
    }


    /**
     event subscribe
     */
    func helperEventSubscribe(st: String, serviceType: String, server: UPnPServer, udn: String, service: UPnPService, properties: [String:String]) -> Void {
        let cp = UPnPControlPoint()

        var handledService = [UPnPService]()
        var handledEvents = [UPnPEventSubscriber]()

        var serviceId: String? = nil

        cp.onScpd {
            (device, service, scpd, error) in

            guard error == nil else {
                // error
                return
            }

            guard let service = service else {
                // error
                return
            }

            guard service.serviceType == serviceType else {
                // not expected service
                return
            }

            serviceId = service.serviceId

            guard let device = device, let udn = device.udn else {
                // error
                return
            }

            cp.subscribe(udn: udn, service: service) {
                (subscriber, error) in
                XCTAssertNil(error)
                guard let subscriber = subscriber else {
                    XCTFail("No Subscriber")
                    return
                }
                XCTAssertNotNil(subscriber.sid)
                print("[SUBSCRIBE] result (SID: '\(subscriber.sid!)')")
                
            }?.onNotification {
                (subscriber, properties, error) in
                guard error == nil else {
                    XCTFail("notification error - \(error!)")
                    return
                }
                guard let subscriber = subscriber else {
                    XCTFail("no subscriber")
                    return
                }
                guard let sid = subscriber.sid else {
                    XCTFail("no sid")
                    return
                }
                XCTAssertNotNil(properties)
                print(" >>> \(sid) <<<\n- \(properties?.description ?? "nil")")

                handledEvents.append(subscriber)
            }

            handledService.append(service)
        }

        cp.addNotificationHandler {
            (subscriber, props, error) in
            print("[EXTRA EVENT LOG] EVENT COME~ '\(props?.description ?? "nil")'")

            guard let subscriber = subscriber else {
                XCTFail("no subscriber")
                return
            }
            handledEvents.append(subscriber)
        }

        cp.addNotificationHandler {
            (subscriber, props, error) in

            guard error == nil else {
                print("[EVENT] Notification Handling Error - \(error!)")
                return
            }

            guard let subscriber = subscriber else {
                XCTFail("no subscriber")
                return
            }

            guard let props = props else {
                XCTFail("no properties")
                return
            }

            XCTAssertEqual(properties.count, props.fields.count)

            XCTAssertNotNil(subscriber.sid)
            print("x [EVENT] Notification (SID: '\(subscriber.sid!)')")
            for field in props.fields {
                print("- Property - '\(field.key)': '\(field.value)'")
                XCTAssertNotNil(properties[field.key])
                XCTAssertEqual(properties[field.key]!, field.value)
            }

            handledEvents.append(subscriber)
        }

        do {
            try cp.run()
            sleep(2)
        } catch let e {
            XCTFail("cp.run() failed \(e)")
            return
        }

        cp.sendMsearch(st: st, mx: 3)

        sleep(3)

        XCTAssertNotNil(service.serviceId)
        server.setProperty(udn: udn, serviceId: service.serviceId!, properties: properties)

        sleep(1)

        XCTAssertNotNil(serviceId)
        if let serviceId = serviceId {
            XCTAssertFalse(cp.getEventSubscribers(forServiceId: serviceId).isEmpty)
        }
        XCTAssertFalse(handledService.isEmpty)
        XCTAssertFalse(handledEvents.isEmpty)
        XCTAssertEqual(handledEvents.count, 3)

        cp.finish()

        usleep(500 * 1000)
        XCTAssertFalse(cp.running)
    }

    /**
     event subscribe and unsubscribe
     */
    func helperEventSubscribeAndUnsubscribe(st: String, serviceType: String, server: UPnPServer, udn: String, service: UPnPService, properties: [String:String]) -> Void {
        let cp = UPnPControlPoint()

        var handledService = [UPnPService]()
        var handledEvents = [UPnPEventSubscriber?]()
        var unsubscribeCalled = false
        var serviceId: String? = nil

        cp.onScpd {
            (device, service, scpd, error) in

            guard error == nil else {
                // error
                return
            }

            guard let service = service else {
                // error
                return
            }

            guard service.serviceType == serviceType else {
                // not expected service
                return
            }

            serviceId = service.serviceId

            guard let device = device, let udn = device.udn else {
                // error
                return
            }

            cp.subscribe(udn: udn, service: service) {
                (subscriber, error) in
                XCTAssertNil(error)
                guard let sub = subscriber else {
                    XCTFail("No Subscriber")
                    return
                }
                XCTAssertNotNil(sub.sid)
                print("[SUBSCRIBE] result (SID: '\(sub.sid!)')")

                DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + 0.1) {

                    XCTAssertNotNil(serviceId)
                    if let serviceId = serviceId {
                        XCTAssertFalse(cp.getEventSubscribers(forServiceId: serviceId).isEmpty)
                    }

                    XCTAssertNotNil(sub.sid)
                    cp.unsubscribe(sid: sub.sid!) {
                        (subscriber, error) in
                        guard error == nil else {
                            XCTFail("unsubscribe - error: \(error!)")
                            return
                        }
                        guard let sid = subscriber?.sid else {
                            XCTFail("unsubscribe - no sid")
                            return
                        }
                        print("\(Date()) - unsubscribed")
                        XCTAssertEqual(sid, sub.sid)
                        unsubscribeCalled = true
                    }
                }
            }

            handledService.append(service)
        }

        cp.addNotificationHandler {
            (subscriber, props, error) in
            handledEvents.append(subscriber)
        }

        do {
            try cp.run()
            sleep(2)
        } catch let e {
            XCTFail("cp.run() failed \(e)")
            return
        }

        cp.sendMsearch(st: st, mx: 3)

        sleep(3)

        XCTAssertNotNil(service.serviceId)
        server.setProperty(udn: udn, serviceId: service.serviceId!, properties: properties)

        sleep(3)

        XCTAssertNotNil(serviceId)
        if let serviceId = serviceId {
            XCTAssertTrue(cp.getEventSubscribers(forServiceId: serviceId).isEmpty)
        }

        XCTAssertFalse(handledService.isEmpty)
        XCTAssertTrue(handledEvents.isEmpty)
        XCTAssertTrue(unsubscribeCalled)

        cp.finish()

        usleep(500 * 1000)
        XCTAssertFalse(cp.running)
    }

    /**
     test control point
     */
    func testControlPoint() {

        guard let server = ServerTests.upnpServer else {
            XCTFail("UPnPServer is not ready")
            return
        }

        guard let device = server.getDevice(udn: "e399855c-7ecb-1fff-8000-000000000000") else {
            XCTFail("server.getDevice failed")
            return
        }

        let service = device.services[0]
        
        server.onActionRequest {
            (service, soapRequest) in
            let properties = OrderedProperties()
            properties["GetLoadlevelTarget"] = "10"
            return properties
        }

        helperControlPointDiscovery(st: "ssdp:all", serviceType: "urn:schemas-upnp-org:service:SwitchPower:1")

        helperControlPointSuspendResume(st: "ssdp:all", serviceType: "urn:schemas-upnp-org:service:SwitchPower:1", server: server, udn: "e399855c-7ecb-1fff-8000-000000000000", service: service, properties: ["GetLoadlevelTarget" : "14"])
    }

    
    /**
     helper control point discovery
     */
    func helperControlPointDiscovery(st: String, serviceType: String) {
        let cp = UPnPControlPoint()

        var handledDevices = [UPnPDevice]()
        var handledScpds = [UPnPScpd]()

        cp.onDeviceAdded {
            (device) in
            print("DEVICE ADDED -- \(device.udn ?? "nil") \(device.deviceType ?? "nil")")

            guard let _ = device.getService(type: serviceType) else {
                // no expected service found
                return
            }
            handledDevices.append(device)
        }

        cp.onScpd {
            (device, service, scpd, error) in

            if let error = error {
                print("ERROR - \(error)")
                XCTAssertEqual(service?.status, .failed)
                return
            }

            guard let service = service else {
                XCTFail("service is nil")
                return
            }

            guard let scpd = scpd else {
                XCTFail("scpd is nil")
                return
            }
            
            XCTAssertNotNil(service.scpd)
            XCTAssertEqual(service.status, .completed)

            XCTAssertNotNil(scpd.getAction(name: "SetLoadLevelTarget"))
            XCTAssertNotNil(scpd.getAction(name: "SetLoadLevelTarget")!.arguments)
            XCTAssertNotNil(scpd.getAction(name: "SetLoadLevelTarget")!.arguments[0])
            XCTAssertEqual("newLoadlevelTarget", scpd.getAction(name: "SetLoadLevelTarget")!.arguments[0].name)
            
            handledScpds.append(scpd)
        }

        do {
            try cp.run()
            sleep(2)
        } catch let e {
            XCTFail("cp.run() failed \(e)")
            return
        }

        cp.sendMsearch(st: st, mx: 3)

        sleep(3)

        XCTAssertFalse(handledDevices.isEmpty)
        XCTAssertFalse(handledScpds.isEmpty)

        cp.finish()

        usleep(500 * 1000)
        XCTAssertFalse(cp.running)
    }

    /**
     suspend resume
     */
    func helperControlPointSuspendResume(st: String, serviceType: String, server: UPnPServer, udn: String, service: UPnPService, properties: [String:String]) -> Void {
        let cp = UPnPControlPoint()

        var handledService = [UPnPService]()
        var handledEvents = [UPnPEventSubscriber]()

        var serviceId: String? = nil

        cp.onScpd {
            (device, service, scpd, error) in

            guard error == nil else {
                // error
                return
            }

            guard let service = service else {
                // error
                return
            }

            guard service.serviceType == serviceType else {
                // not expected service
                return
            }

            serviceId = service.serviceId

            guard let device = device, let udn = device.udn else {
                // error
                return
            }

            if cp.getEventSubscribers(forUdn: udn).isEmpty {
                cp.subscribe(udn: udn, service: service) {
                    (subscriber, error) in
                    XCTAssertNil(error)
                    guard let subscriber = subscriber else {
                        XCTFail("No Subscriber")
                        return
                    }
                    XCTAssertNotNil(subscriber.sid)
                    print("[SUBSCRIBE] result (SID: '\(subscriber.sid!)')")

                    subscriber.onNotification {
                        (subscriber, properties, error) in
                        guard let subscriber = subscriber else {
                            XCTFail("subscriber is nil")
                            return
                        }
                        print("SID - '\(subscriber.sid ?? "nil")'\n\(properties?.description ?? "nil")")
                        handledEvents.append(subscriber)
                    }
                }
            }

            handledService.append(service)
        }

        cp.addNotificationHandler {
            (subscriber, props, error) in

            guard error == nil else {
                print("[EVENT] Notification Handling Error - \(error!)")
                return
            }
            
            guard let subscriber = subscriber else {
                XCTFail("subscriber is nil")
                return
            }

            XCTAssertNotNil(properties)
            guard let props = props else {
                return
            }

            XCTAssertEqual(properties.count, props.fields.count)

            XCTAssertNotNil(subscriber.sid)
            print("x [EVENT] Notification (SID: '\(subscriber.sid!)')")
            for field in props.fields {
                print("- Property - '\(field.key)': '\(field.value)'")
                XCTAssertNotNil(properties[field.key])
                XCTAssertEqual(properties[field.key]!, field.value)
            }

            handledEvents.append(subscriber)
        }

        do {
            try cp.run()
            sleep(2)
        } catch let e {
            XCTFail("cp.run() failed \(e)")
            return
        }

        cp.sendMsearch(st: st, mx: 3)

        sleep(3)

        XCTAssertNotNil(service.serviceId)
        server.setProperty(udn: udn, serviceId: service.serviceId!, properties: properties)

        sleep(1)

        XCTAssertNotNil(serviceId)
        if let serviceId = serviceId {
            XCTAssertFalse(cp.getEventSubscribers(forServiceId: serviceId).isEmpty)
        }


        // ----------------------

        cp.suspend()

        sleep(1)

        do {
            try cp.resume()
        } catch let err {
            XCTFail("cp.resume() failed - \(err)")
        }

        sleep(1)

        XCTAssertNotNil(service.serviceId)
        server.setProperty(udn: udn, serviceId: service.serviceId!, properties: properties)

        sleep(1)

        // ---------------------------
        
        XCTAssertFalse(handledService.isEmpty)
        XCTAssertFalse(handledEvents.isEmpty)
        XCTAssertEqual(4, handledEvents.count)

        cp.finish()

        usleep(500 * 1000)
        XCTAssertFalse(cp.running)
    }

    /**
     all tests
     */
    static var allTests = [
      ("testNotify", testNotify),
      ("testServer", testServer),
      ("testControlPoint", testControlPoint),
    ]

    /**
     device description urn:schemas-upnp-org:device:DimmableLight:1
     */
    static var deviceDescription_DimmableLight = "<?xml version=\"1.0\"?>" +
      "<root xmlns=\"urn:schemas-upnp-org:device-1-0\">" +
      "  <specVersion>" +
      "  <major>1</major>" +
      "  <minor>0</minor>" +
      "  </specVersion>" +
      "  <device>" +
      "  <deviceType>urn:schemas-upnp-org:device:DimmableLight:1</deviceType>" +
      "  <friendlyName>UPnP Sample Dimmable Light ver.1</friendlyName>" +
      "  <manufacturer>Testers</manufacturer>" +
      "  <manufacturerURL>www.example.com</manufacturerURL>" +
      "  <modelDescription>UPnP Test Device</modelDescription>" +
      "  <modelName>UPnP Test Device</modelName>" +
      "  <modelNumber>1</modelNumber>" +
      "  <modelURL>www.example.com</modelURL>" +
      "  <serialNumber>12345678</serialNumber>" +
      "  <UDN>e399855c-7ecb-1fff-8000-000000000000</UDN>" +
      "  <serviceList>" +
      "    <service>" +
      "    <serviceType>urn:schemas-upnp-org:service:SwitchPower:1</serviceType>" +
      "    <serviceId>urn:upnp-org:serviceId:SwitchPower.1</serviceId>" +
      "    <SCPDURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/scpd.xml</SCPDURL>" +
      "    <controlURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/control.xml</controlURL>" +
      "    <eventSubURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/event.xml</eventSubURL>" +
      "    </service>" +
      "    <service>" +
      "    <serviceType>urn:schemas-upnp-org:service:Dimming:1</serviceType>" +
      "    <serviceId>urn:upnp-org:serviceId:Dimming.1</serviceId>" +
      "    <SCPDURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:Dimming:1/scpd.xml</SCPDURL>" +
      "    <controlURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:Dimming:1/control.xml</controlURL>" +
      "    <eventSubURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:Dimming:1/event.xml</eventSubURL>" +
      "    </service>" +
      "  </serviceList>" +
      "  </device>" +
      "</root>"

    /**
     scpd urn:schemas-upnp-org:service:SwitchPower:1
     */
    static var scpd_SwitchPower = "<?xml version=\"1.0\"?>" +
      "<scpd xmlns=\"urn:schemas-upnp-org:service-1-0\">" +
      "  <specVersion>" +
      " <major>1</major>" +
      " <minor>0</minor>" +
      "  </specVersion>" +
      "  <actionList>" +
      " <action>" +
      "   <name>SetLoadLevelTarget</name>" +
      "   <argumentList>" +
      "  <argument>" +
      "    <name>newLoadlevelTarget</name>" +
      "    <direction>in</direction>" +
      "    <relatedStateVariable>LoadLevelTarget</relatedStateVariable>" +
      "  </argument>" +
      "   </argumentList>" +
      " </action>" +
      " <action>" +
      "   <name>GetLoadLevelTarget</name>" +
      "   <argumentList>" +
      "  <argument>" +
      "    <name>GetLoadlevelTarget</name>" +
      "    <direction>out</direction>" +
      "    <relatedStateVariable>LoadLevelTarget</relatedStateVariable>" +
      "  </argument>" +
      "   </argumentList>" +
      " </action>" +
      " <action>" +
      "   <name>GetLoadLevelStatus</name>" +
      "   <argumentList>" +
      "  <argument>" +
      "    <name>retLoadlevelStatus</name>" +
      "    <direction>out</direction>" +
      "    <relatedStateVariable>LoadLevelStatus</relatedStateVariable>" +
      "  </argument>" +
      "   </argumentList>" +
      " </action>" +
      "  </actionList>" +
      "  <serviceStateTable>" +
      " <stateVariable sendEvents=\"no\">" +
      "   <name>LoadLevelTarget</name>" +
      "   <dataType>ui1</dataType>" +
      " </stateVariable>" +
      " <stateVariable sendEvents=\"yes\">" +
      "   <name>LoadLevelStatus</name>" +
      "   <dataType>ui1</dataType>" +
      " </stateVariable>" +
      "  </serviceStateTable>" +
      "</scpd>"
}
