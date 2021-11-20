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

    class func startServer() -> UPnPServer {
        let server = UPnPServer(httpServerBindPort: 0)
        server.run()
        return server
    }

    override class func tearDown() {
        print("-- TEAR DOWN --")
        super.tearDown()
        ServerTests.upnpServer?.finish()
        print("-- TEAR DOWN :: DONE --")
    }

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

    func testServer() {

        guard let server = ServerTests.upnpServer else {
            return
        }

        guard let device = UPnPDevice.read(xmlString: deviceDescription) else {
            return
        }
        
        server.registerDevice(device: device)
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
   
    func testNotify() {
        guard let device = UPnPDevice.read(xmlString: deviceDescription) else {
            return
        }
        guard let addr = Network.getInetAddress() else {
            XCTAssert(false)
            return
        }
        UPnPServer.activate(device: device, location: "http://\(addr.hostname)/dummy")
        UPnPServer.deactivate(device: device)
    }
    
    static var allTests = [
      ("testServer", testServer),
      ("testNotify", testNotify),
    ]

    var deviceDescription = "<?xml version=\"1.0\"?>" +
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
}
