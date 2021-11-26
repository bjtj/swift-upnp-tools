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

        // print(upnpServer?.httpServer?.serverAddress?.description)

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
            receiver = SSDPReceiver() {
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
                print("[ACTION INVOKE] soapResponse: \(soapResponse.description)")
            }
            XCTAssertEqual(soapResponse?["GetLoadlevelTarget"], "10")
        }

        // -------------------------------------------

        let service = device!.getService(type: "urn:schemas-upnp-org:service:SwitchPower:1")
        XCTAssertNotNil(service)
        XCTAssertNotNil(device!.udn)
        helperEventSubscribe(st: "ssdp:all", serviceType: "urn:schemas-upnp-org:service:SwitchPower:1", server: server, udn: device!.udn!, service: service!, properties: ["GetLoadlevelTarget" : "12"])

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
                                        handler: (UPnPActionInvokeDelegate)?)
    {
        let cp = UPnPControlPoint(httpServerBindPort: 0)

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
        } catch let e {
            XCTFail("cp.run() failed \(e)")
        }

        sleep(1)

        // print(cp.httpServer?.serverAddress?.description)

        cp.sendMsearch(st: st, mx: 3)

        print("... Wait ...")
        sleep(5)
        print("............")

        XCTAssertFalse(handledService.isEmpty)
        
        cp.finish()
    }


    /**
     event subscribe
     */
    func helperEventSubscribe(st: String, serviceType: String, server: UPnPServer, udn: String, service: UPnPService, properties: [String:String]) -> Void {
        let cp = UPnPControlPoint()

        var handledService = [UPnPService]()
        var handledEvents = [UPnPEventSubscription]()

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

            guard let device = device, let udn = device.udn else {
                // error
                return
            }

            let _ = cp.subscribe(udn: udn, service: service) {
                (subscription, error) in
                XCTAssertNil(error)
                guard let sub = subscription else {
                    XCTFail("No Subscription")
                    return
                }
                XCTAssertNotNil(sub.sid)
                print("[SUBSCRIBE] result (SID: '\(sub.sid)')")
            }

            handledService.append(service)
        }

        cp.addEventNotificationHandler {
            (subscription, props, error) in
            print("[EXTRA EVENT LOG] EVENT COME~ '\(props?.description ?? "nil")'")
        }

        cp.addEventNotificationHandler {
            (subscription, props, error) in

            guard error == nil else {
                print("[EVENT] Notification Handling Error - \(error!)")
                return
            }

            XCTAssertNotNil(subscription)
            guard let subscription = subscription else {
                return
            }

            XCTAssertNotNil(properties)
            guard let props = props else {
                return
            }

            XCTAssertEqual(properties.count, props.fields.count)

            print("[EVENT] Notification (SID: '\(subscription.sid)')")
            for field in props.fields {
                print(" - Property - '\(field.key)': '\(field.value)'")
                XCTAssertNotNil(properties[field.key])
                XCTAssertEqual(properties[field.key]!, field.value)
            }

            handledEvents.append(subscription)
        }

        do {
            try cp.run()
        } catch let e {
            XCTFail("cp.run() failed \(e)")
        }

        sleep(1)

        // print(cp.httpServer?.serverAddress?.description)

        cp.sendMsearch(st: st, mx: 3)

        print("... Wait ...")
        sleep(5)
        print("............")

        XCTAssertNotNil(service.serviceId)
        server.setProperty(udn: udn, serviceId: service.serviceId!, properties: properties)

        sleep(1)

        XCTAssertFalse(handledService.isEmpty)
        XCTAssertFalse(handledEvents.isEmpty)
        
        cp.finish()
    }

    /**
     test control point
     */
    func testControlPoint() {

        guard let server = ServerTests.upnpServer else {
            XCTFail("UPnPServer is not ready")
            return
        }

        XCTAssertNotNil(server.getDevice(udn: "e399855c-7ecb-1fff-8000-000000000000"))
        
        server.onActionRequest {
            (service, soapRequest) in
            let properties = OrderedProperties()
            properties["GetLoadlevelTarget"] = "10"
            return properties
        }

        helperControlPointDiscovery(st: "ssdp:all", serviceType: "urn:schemas-upnp-org:service:SwitchPower:1")
    }
    
    /**
     helper control point discovery
     */
    func helperControlPointDiscovery(st: String, serviceType: String) {
        let cp = UPnPControlPoint(httpServerBindPort: 0)

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
                XCTAssertEqual(service?.buildStatus, .failed)
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
            XCTAssertEqual(service.buildStatus, .completed)

            XCTAssertNotNil(scpd.getAction(name: "SetLoadLevelTarget"))
            XCTAssertNotNil(scpd.getAction(name: "SetLoadLevelTarget")!.arguments)
            XCTAssertNotNil(scpd.getAction(name: "SetLoadLevelTarget")!.arguments[0])
            XCTAssertEqual("newLoadlevelTarget", scpd.getAction(name: "SetLoadLevelTarget")!.arguments[0].name)
            
            handledScpds.append(scpd)
        }

        do {
            try cp.run()
        } catch let e {
            XCTFail("cp.run() failed \(e)")
        }

        sleep(1)

        // print(cp.httpServer?.serverAddress?.description)

        cp.sendMsearch(st: st, mx: 3)

        for _ in 0..<6 {
            usleep(1000 * 1000)
        }

        XCTAssertFalse(handledDevices.isEmpty)
        XCTAssertFalse(handledScpds.isEmpty)
        
        cp.finish()
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
