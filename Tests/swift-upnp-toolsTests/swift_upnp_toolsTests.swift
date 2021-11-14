//
// swift_upnp_toolsTests.swift
// 

import XCTest
@testable import SwiftUpnpTools
import SwiftHttpServer

/**
 swift_upnp_toolsTests
 */
final class swift_upnp_toolsTests: XCTestCase {

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

    override class func tearDown() {
        print("-- TEAR DOWN --")
        super.tearDown()
        swift_upnp_toolsTests.upnpServer?.finish()
        print("-- TEAR DOWN :: DONE --")
    }

    class func startReceiver() {
        DispatchQueue.global(qos: .background).async {
            do {
                print("receiver start")
                let receiver = SSDPReceiver() {
                    (address, ssdpHeader) in
                    if let ssdpHeader = ssdpHeader {
                        if let address = address {
                            print("from -- \(address.hostname):\(address.port)")
                        }
                        print(ssdpHeader.description)
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

    func testSsdp() {
        XCTAssertEqual(SSDP.MCAST_HOST, "239.255.255.250")
        XCTAssertEqual(SSDP.MCAST_PORT, 1900)
    }

    func testSsdpHeader() {
        let header = SSDPHeader()
        let location = "http://example.com"
        header["Location"] = location
        XCTAssertEqual(header["Location"], location)
        XCTAssertEqual(header["LOCATION"], location)
        XCTAssertEqual(header["location"], location)
    }

    func testSsdpHeaderToString() {
        let header = SSDPHeader()
        let location = "http://example.com"
        header["Location"] = location
        XCTAssertEqual(header.description, "\r\nLocation: http://example.com\r\n\r\n")
    }

    func testSsdpHeaderFromString() {
        let text = "M-SEARCH * HTTP/1.1\r\n" +
          "HOST: \(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)\r\n" +
          "MAN: \"ssdp:discover\"\r\n" +
          "MX: 3\r\n" +
          "ST: ssdp:all\r\n" +
          "\r\n"
        let header = SSDPHeader.read(text: text)
        XCTAssertEqual(header.description, text)

        XCTAssertEqual(header.firstLineParts[0], "M-SEARCH")
        XCTAssertEqual(header.firstLineParts[1], "*")
        XCTAssertEqual(header.firstLineParts[2], "HTTP/1.1")

        XCTAssert(header.isMsearch)
    }

    func testUPnPModel() {
        let model = UPnPModel()
        let udn = NSUUID().uuidString.lowercased()
        model["UDN"] = udn
        XCTAssertEqual(model["UDN"], udn)
    }

    func testUsn() {
        var usn = UPnPUsn.read(text: "uuid:fake::urn:subtype")
        XCTAssertEqual(usn.uuid, "uuid:fake")
        XCTAssertEqual(usn.type, "urn:subtype")
        XCTAssertEqual(usn.description, "uuid:fake::urn:subtype")

        usn = UPnPUsn.read(text: "uuid:fake")
        XCTAssertEqual(usn.uuid, "uuid:fake")
        XCTAssert(usn.type.isEmpty)
        XCTAssertEqual(usn.description, "uuid:fake")
    }

    func testXml() {
        let tag = XmlTag(content: "")
        tag.name = "a"
        XCTAssertEqual("<a />", tag.description)

        tag.namespace = "x"
        XCTAssertEqual("<x:a />", tag.description)

        tag.content = "A"
        XCTAssertEqual("<x:a>A</x:a>", tag.description)

        tag.content = XmlTag(name: "wow", content: "").description
        XCTAssertEqual("<x:a><wow /></x:a>", tag.description)
    }

    func testDeviceDescription() {
        guard let device = UPnPDevice.read(xmlString: deviceDescription) else {
            XCTAssert(false)
            return
        }
        
        XCTAssertEqual("UPnP Sample Dimmable Light ver.1", device.friendlyName)
    }

    func testScpd() {
        guard let scpd = UPnPScpd.read(xmlString: scpd) else {
            XCTAssert(false)
            return
        }

        XCTAssertEqual("SetLoadLevelTarget", scpd.actions[0].name!)
        XCTAssertEqual("GetLoadLevelTarget", scpd.actions[1].name!)
        XCTAssertEqual("GetLoadLevelStatus", scpd.actions[2].name!)
        XCTAssertEqual("LoadLevelTarget", scpd.stateVariables[0].name!)
        XCTAssertEqual("LoadLevelStatus", scpd.stateVariables[1].name!)
    }

    func testSoap() {
        guard let request = UPnPSoapRequest.read(xmlString: soapRequest) else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual("urn:schemas-upnp-org:service:SwitchPower:1#SetTarget", request.soapaction)

        print(request.xmlDocument)
        
        guard let response = UPnPSoapResponse.read(xmlString: soapResponse) else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual("urn:schemas-upnp-org:service:ContentDirectory:1", response.serviceType)
        XCTAssertEqual("Browse", response.actionName)

        print(response.xmlDocument)
    }

    func testProperty() {
        guard let props = UPnPEventProperties.read(xmlString: propertyXml) else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual("", props["ContainerUpdateIDs"])
        XCTAssertEqual("76185766", props["SystemUpdateID"])

        print(props.xmlDocument)
    }

    func testServer() {

        guard let server = swift_upnp_toolsTests.upnpServer else {
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

        let cp = UPnPControlPoint(httpServerBindPort: 0)

        cp.onDeviceAdded {
            (device) in
            DispatchQueue.global(qos: .background).async {
                print("DEVICE ADDED -- \(device.udn ?? "nil") \(device.deviceType ?? "nil")")

                guard let service = device.getService(type: "urn:schemas-upnp-org:service:SwitchPower:1") else {
                    print("no service")
                    return
                }

                let actionName = "GetLoadLevelTarget"
                let fields = OrderedProperties()
                print("Invoke Action1")
                cp.invoke(service: service, actionName: actionName, fields: fields) {
                    (soapResponse) in
                    print("action response")
                    XCTAssertEqual(soapResponse?["GetLoadlevelTarget"], "10")
                }

                print("Invoke Action2")
                let actionRequest = UPnPActionRequest(actionName: actionName, fields: fields)
                cp.invoke(service: service, actionRequest: actionRequest) {
                    (soapResponse) in
                    print("action response")
                    XCTAssertEqual(soapResponse?["GetLoadlevelTarget"], "10")
                }

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
        cp.sendMsearch(st: "ssdp:all", mx: 3)

        for _ in 0..<60 {
            usleep(100 * 1000)
        }

        XCTAssert(cp.devices.isEmpty == false)
        
        cp.finish()
    }

    class func startServer() -> UPnPServer {
        let server = UPnPServer(httpServerBindPort: 0)
        server.run()
        return server
    }

    func testSsdpReceiver() {
        print("send notify")
        let properties = OrderedProperties()
        properties["x"] = "x"
        SSDP.notify(properties: properties)
        print("send msearch")
        SSDP.sendMsearch(st: "ssdp:all", mx: 1)
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
      ("testSsdp", testSsdp),
      ("testSsdpHeader", testSsdpHeader),
      ("testSsdpHeaderToString", testSsdpHeaderToString),
      ("testSsdpHeaderFromString", testSsdpHeaderFromString),
      ("testUPnPModel", testUPnPModel),
      ("testUsn", testUsn),
      ("testXml", testXml),
      ("testDeviceDescription", testDeviceDescription),
      ("testScpd", testScpd),
      ("testSoap", testSoap),
      ("testProperty", testProperty),
      ("testServer", testServer),
      ("testSsdpReceiver", testSsdpReceiver),
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

    var scpd = "<?xml version=\"1.0\"?>" +
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

    var soapRequest = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" +
      "<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"" +
      "      xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">" +
      "  <s:Body>" +
      "  <u:SetTarget xmlns:u=\"urn:schemas-upnp-org:service:SwitchPower:1\">" +
      "    <newTargetValue>10</newTargetValue>" +
      "  </u:SetTarget>" +
      "  </s:Body>" +
      "</s:Envelope>"

    var soapResponse = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
      "<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">" +
      "  <s:Body>" +
      "  <u:BrowseResponse xmlns:u=\"urn:schemas-upnp-org:service:ContentDirectory:1\">" +
      "    <Result>&lt;DIDL-Lite xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:upnp=\"urn:schemas-upnp-org:metadata-1-0/upnp/\" xmlns:dlna=\"urn:schemas-dlna-org:metadata-1-0/\"&gt;&lt;container id=\"94467912-bd40-4d2f-ad25-7b8423f7b05a\" parentID=\"0\" restricted=\"1\" searchable=\"0\"&gt;&lt;dc:title&gt;Video&lt;/dc:title&gt;&lt;dc:creator&gt;Unknown&lt;/dc:creator&gt;&lt;upnp:genre&gt;Unknown&lt;/upnp:genre&gt;&lt;dc:description&gt;Video&lt;/dc:description&gt;&lt;upnp:class&gt;object.container.storageFolder&lt;/upnp:class&gt;&lt;/container&gt;&lt;container id=\"abe6121c-1731-4683-815c-89e1dcd2bf11\" parentID=\"0\" restricted=\"1\" searchable=\"0\"&gt;&lt;dc:title&gt;Music&lt;/dc:title&gt;&lt;dc:creator&gt;Unknown&lt;/dc:creator&gt;&lt;upnp:genre&gt;Unknown&lt;/upnp:genre&gt;&lt;dc:description&gt;Music&lt;/dc:description&gt;&lt;upnp:class&gt;object.container.storageFolder&lt;/upnp:class&gt;&lt;/container&gt;&lt;container id=\"b0184133-f840-4a4f-a583-45f99645edcd\" parentID=\"0\" restricted=\"1\" searchable=\"0\"&gt;&lt;dc:title&gt;Photos&lt;/dc:title&gt;&lt;dc:creator&gt;Unknown&lt;/dc:creator&gt;&lt;upnp:genre&gt;Unknown&lt;/upnp:genre&gt;&lt;dc:description&gt;Photos&lt;/dc:description&gt;&lt;upnp:class&gt;object.container.storageFolder&lt;/upnp:class&gt;&lt;/container&gt;&lt;/DIDL-Lite&gt;</Result>" +
      "  <NumberReturned>3</NumberReturned><TotalMatches>3</TotalMatches><UpdateID>76229067</UpdateID></u:BrowseResponse>" +
      "  </s:Body>" +
      "</s:Envelope>"

    var propertyXml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
      "<e:propertyset xmlns:e=\"urn:schemas-upnp-org:event-1-0\">" +
      "  <e:property>" +
      "  <ContainerUpdateIDs></ContainerUpdateIDs>" +
      "  </e:property>" +
      "  <e:property>" +
      "  <SystemUpdateID>76185766</SystemUpdateID>" +
      "  </e:property>" +
      "</e:propertyset>"
}
