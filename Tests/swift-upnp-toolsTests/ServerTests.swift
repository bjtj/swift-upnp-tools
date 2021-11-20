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

    /**
     set up
     */
    override class func setUp() {
        super.setUp()

        print("-- SET UP --")

        startReceiver()
        DispatchQueue.global(qos: .background).async {
            upnpServer = startServer()
        }
        
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
        print("-- TEAR DOWN :: DONE --")
    }

    /**
     start receiver
     */
    class func startReceiver() {
        DispatchQueue.global(qos: .background).async {
            do {
                let receiver = SSDPReceiver() {
                    (address, ssdpHeader) in
                    if let ssdpHeader = ssdpHeader {
                        if let address = address {
                            print("from -- \(address.hostname):\(address.port) / \(ssdpHeader.nts?.rawValue ?? "(NO NTS)")")
                        }
                    }
                    return nil
                }
                try receiver.run()
            } catch let error {
                print(error)
            }
            print("receiver done")
        }
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

        XCTAssertNotNil(server.getDevice(udn: "e399855c-7ecb-1fff-8000-000000000000"))

        server.onActionRequest {
            (service, soapRequest) in
            let properties = OrderedProperties()
            properties["GetLoadlevelTarget"] = "10"
            return properties
        }

        let actionRequest = UPnPActionRequest(actionName: "GetLoadLevelTarget")
        helperControlPointInvokeAction(st: "ssdp:all",
                                       serviceType: "urn:schemas-upnp-org:service:SwitchPower:1",
                                       actionRequest: actionRequest)
        {
            (soapResponse) in 
            XCTAssertEqual(soapResponse?["GetLoadlevelTarget"], "10")
        }
    }

    /**
     helper control point invoke action
     */
    func helperControlPointInvokeAction(st: String,
                                        serviceType: String,
                                        actionRequest: UPnPActionRequest,
                                        handler: ((UPnPSoapResponse?) -> Void)?)
    {
        let cp = UPnPControlPoint(httpServerBindPort: 0)

        cp.onDeviceAdded {
            (device) in
            DispatchQueue.global(qos: .background).async {
                print("DEVICE ADDED -- \(device.udn ?? "nil") \(device.deviceType ?? "nil")")

                guard let service = device.getService(type: serviceType) else {
                    // no expected service found
                    return
                }

                cp.invoke(service: service, actionRequest: actionRequest, completeHandler: handler)

                let _ = cp.subscribe(service: service) {
                    (subscription) in
                    print("subscribe result -- sid: \(subscription.sid)")
                }
            }
        }

        cp.onEventProperty {
            (sid, properties) in
            print("sid -- \(sid)")
            for field in properties.fields {
                print("\(field.key) = \(field.value)")
            }
        }

        cp.run()
        cp.sendMsearch(st: st, mx: 3)

        for _ in 0..<60 {
            usleep(100 * 1000)
        }

        XCTAssert(cp.devices.isEmpty == false)
        
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
            DispatchQueue.global(qos: .background).async {
                print("DEVICE ADDED -- \(device.udn ?? "nil") \(device.deviceType ?? "nil")")

                guard let _ = device.getService(type: serviceType) else {
                    // no expected service found
                    return
                }
                handledDevices.append(device)
            }
        }

        cp.onScpd {
            (service, scpd) in
            print("on scpd")
            XCTAssertNotNil(service.scpd)
            handledScpds.append(scpd)
        }

        cp.run()
        cp.sendMsearch(st: st, mx: 3)

        for _ in 0..<60 {
            usleep(100 * 1000)
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
