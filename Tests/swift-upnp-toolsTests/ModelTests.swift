//
// ModelTests.swift
// 

import XCTest
@testable import SwiftUpnpTools
import SwiftHttpServer
import SwiftXml

/**
 ModelTests
 */
final class ModelTests: XCTestCase {

    /**
     test upnp model
     */
    func testUPnPModel() {
        let model = UPnPModel()
        let udn = NSUUID().uuidString.lowercased()
        model["UDN"] = udn
        XCTAssertEqual(model["UDN"], udn)
    }

    /**
     test usn
     */
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

    /**
     test xml
     */
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

    /**
     test device description
     */
    func testDeviceDescription() {

        let deviceDescription = "<?xml version=\"1.0\"?>" +
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
        
        guard let device = UPnPDevice.read(xmlString: deviceDescription) else {
            XCTAssert(false)
            return
        }
        
        XCTAssertEqual("UPnP Sample Dimmable Light ver.1", device.friendlyName)
    }

    /**
     test scpd
     */
    func testScpd() {

        let scpd_xml = "<?xml version=\"1.0\"?>" +
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
        
        guard let scpd = UPnPScpd.read(xmlString: scpd_xml) else {
            XCTAssert(false)
            return
        }

        XCTAssertEqual("SetLoadLevelTarget", scpd.actions[0].name!)
        XCTAssertEqual("GetLoadLevelTarget", scpd.actions[1].name!)
        XCTAssertEqual("GetLoadLevelStatus", scpd.actions[2].name!)
        XCTAssertEqual("LoadLevelTarget", scpd.stateVariables[0].name!)
        XCTAssertEqual("LoadLevelStatus", scpd.stateVariables[1].name!)
    }


    /**
     test servcie
     */
    func testService() {

        let scpd_xml = "<?xml version=\"1.0\"?>" +
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
        
        guard let scpd = UPnPScpd.read(xmlString: scpd_xml) else {
            XCTAssert(false)
            return
        }

        let service = UPnPService()
        service.scpd = scpd
        service.scpdUrl = "/scpd.xml"

        let device = UPnPDevice()
        device.baseUrl = URL(string: "http://example.com")

        device.addService(service: service)
        
        XCTAssertEqual(URL(string: "http://example.com/scpd.xml")?.absoluteString, service.fullUrl(relativeUrl: "scpd.xml")?.absoluteString)
        XCTAssertEqual(URL(string: "http://example.com/scpd.xml")?.absoluteString, service.fullUrl(relativeUrl: "/scpd.xml")?.absoluteString)
        XCTAssertEqual(URL(string: "http://example.com/scpd.xml")?.absoluteString, service.scpdUrlFull?.absoluteString)

        device.baseUrl = URL(string: "http://example.com/svc/")

        XCTAssertEqual(URL(string: "http://example.com/svc/scpd.xml")?.absoluteString, service.fullUrl(relativeUrl: "scpd.xml")?.absoluteString)
        XCTAssertEqual(URL(string: "http://example.com/scpd.xml")?.absoluteString, service.fullUrl(relativeUrl: "/scpd.xml")?.absoluteString)
        XCTAssertEqual(URL(string: "http://example.com/scpd.xml")?.absoluteString, service.scpdUrlFull?.absoluteString)

        XCTAssertNotNil(device.getService(withScpdUrl: "/scpd.xml"))
    }

    /**
     test soap
     */
    func testSoap() {

        let soapRequest = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" +
          "<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"" +
          "      xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">" +
          "  <s:Body>" +
          "  <u:SetTarget xmlns:u=\"urn:schemas-upnp-org:service:SwitchPower:1\">" +
          "    <newTargetValue>10</newTargetValue>" +
          "  </u:SetTarget>" +
          "  </s:Body>" +
          "</s:Envelope>"
        
        guard let request = UPnPSoapRequest.read(xmlString: soapRequest) else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual("urn:schemas-upnp-org:service:SwitchPower:1#SetTarget", request.soapaction)

        // --

        let soapResponse = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
          "<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">" +
          "  <s:Body>" +
          "  <u:BrowseResponse xmlns:u=\"urn:schemas-upnp-org:service:ContentDirectory:1\">" +
          "    <Result>&lt;DIDL-Lite xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:upnp=\"urn:schemas-upnp-org:metadata-1-0/upnp/\" xmlns:dlna=\"urn:schemas-dlna-org:metadata-1-0/\"&gt;&lt;container id=\"94467912-bd40-4d2f-ad25-7b8423f7b05a\" parentID=\"0\" restricted=\"1\" searchable=\"0\"&gt;&lt;dc:title&gt;Video&lt;/dc:title&gt;&lt;dc:creator&gt;Unknown&lt;/dc:creator&gt;&lt;upnp:genre&gt;Unknown&lt;/upnp:genre&gt;&lt;dc:description&gt;Video&lt;/dc:description&gt;&lt;upnp:class&gt;object.container.storageFolder&lt;/upnp:class&gt;&lt;/container&gt;&lt;container id=\"abe6121c-1731-4683-815c-89e1dcd2bf11\" parentID=\"0\" restricted=\"1\" searchable=\"0\"&gt;&lt;dc:title&gt;Music&lt;/dc:title&gt;&lt;dc:creator&gt;Unknown&lt;/dc:creator&gt;&lt;upnp:genre&gt;Unknown&lt;/upnp:genre&gt;&lt;dc:description&gt;Music&lt;/dc:description&gt;&lt;upnp:class&gt;object.container.storageFolder&lt;/upnp:class&gt;&lt;/container&gt;&lt;container id=\"b0184133-f840-4a4f-a583-45f99645edcd\" parentID=\"0\" restricted=\"1\" searchable=\"0\"&gt;&lt;dc:title&gt;Photos&lt;/dc:title&gt;&lt;dc:creator&gt;Unknown&lt;/dc:creator&gt;&lt;upnp:genre&gt;Unknown&lt;/upnp:genre&gt;&lt;dc:description&gt;Photos&lt;/dc:description&gt;&lt;upnp:class&gt;object.container.storageFolder&lt;/upnp:class&gt;&lt;/container&gt;&lt;/DIDL-Lite&gt;</Result>" +
          "  <NumberReturned>3</NumberReturned><TotalMatches>3</TotalMatches><UpdateID>76229067</UpdateID></u:BrowseResponse>" +
          "  </s:Body>" +
          "</s:Envelope>"
        
        guard let response = UPnPSoapResponse.read(xmlString: soapResponse) else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual("urn:schemas-upnp-org:service:ContentDirectory:1", response.serviceType)
        XCTAssertEqual("Browse", response.actionName)
    }

    /**
     test action
     */
    func testAction() {
        let action = UPnPActionRequest(actionName: "aBc")
        XCTAssertEqual(action.actionName, "aBc")
    }

    /**
     test action argument 
     */
    func testActionArgument() {
        let argumentXml = "  <argument>" +
          "    <name>GetLoadlevelTarget</name>" +
          "    <direction>out</direction>" +
          "    <relatedStateVariable>LoadLevelTarget</relatedStateVariable>" +
          "  </argument>"

        let doc = parseXml(xmlString: argumentXml)
        guard let root = doc.rootElement else {
            XCTFail("parsing xml error")
            return
        }
        
        let argument = UPnPActionArgument.read(xmlElement: root)
        XCTAssertEqual(argument.name, "GetLoadlevelTarget")
        XCTAssertEqual(argument.direction, UPnPActionArgumentDirection.input)
        XCTAssertEqual(argument.relatedStateVariable, "LoadLevelTarget")
    }


    /**
     test property
     */
    func testProperty() {
        let propertyXml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
          "<e:propertyset xmlns:e=\"urn:schemas-upnp-org:event-1-0\">" +
          "  <e:property>" +
          "  <ContainerUpdateIDs></ContainerUpdateIDs>" +
          "  </e:property>" +
          "  <e:property>" +
          "  <SystemUpdateID>76185766</SystemUpdateID>" +
          "  </e:property>" +
          "</e:propertyset>"
        
        guard let props = UPnPEventProperties.read(xmlString: propertyXml) else {
            XCTAssert(false)
            return
        }
        helperTestProperties(props: props)

        // --
        
        guard let props2 = UPnPEventProperties.read(xmlString: props.xmlDocument) else {
            XCTAssert(false)
            return
        }
        helperTestProperties(props: props2)
    }


    /**
     helper test properties
     */
    func helperTestProperties(props: UPnPEventProperties)  {
        XCTAssertEqual("", props["ContainerUpdateIDs"])
        XCTAssertEqual("76185766", props["SystemUpdateID"])
    }

    /**
     all tests
     */
    static var allTests = [
      ("testUPnPModel", testUPnPModel),
      ("testUsn", testUsn),
      ("testXml", testXml),
      ("testDeviceDescription", testDeviceDescription),
      ("testScpd", testScpd),
      ("testService", testService),
      ("testSoap", testSoap),
      ("testAction", testAction),
      ("testProperty", testProperty),
    ]


    
}
