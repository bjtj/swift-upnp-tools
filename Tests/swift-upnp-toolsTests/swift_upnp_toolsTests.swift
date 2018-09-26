import XCTest
@testable import swift_upnp_tools

final class swift_upnp_toolsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(swift_upnp_tools().text, "Hello, World!")
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
        let tag = XmlTag()
        tag.name = "a"
        XCTAssertEqual("<a />", tag.description)

        tag.namespace = "x"
        XCTAssertEqual("<x:a />", tag.description)

        tag.content = "A"
        XCTAssertEqual("<x:a>A</x:a>", tag.description)

        tag.content = XmlTag(name: "wow").description
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

        for action in scpd.actions {
            if let name = action.name {
                print(name)
            }            
        }

        for stateVariable in scpd.stateVariables {
            if let name = stateVariable.name {
                print(name)
            }
        }
    }

    static var allTests = [
      ("testExample", testExample),
      ("testSsdp", testSsdp),
      ("testSsdpHeader", testSsdpHeader),
      ("testSsdpHeaderToString", testSsdpHeaderToString),
      ("testSsdpHeaderFromString", testSsdpHeaderFromString),
      ("testUPnPModel", testUPnPModel),
      ("testUsn", testUsn),
      ("testXml", testXml),
      ("testDeviceDescription", testDeviceDescription),
      ("testScpd", testScpd),
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
}
