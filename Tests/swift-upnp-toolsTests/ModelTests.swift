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
     test property
     */
    func testProperty() throws {
        let propertyXml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
          "<e:propertyset xmlns:e=\"urn:schemas-upnp-org:event-1-0\">" +
          "  <e:property>" +
          "  <ContainerUpdateIDs></ContainerUpdateIDs>" +
          "  </e:property>" +
          "  <e:property>" +
          "  <SystemUpdateID>76185766</SystemUpdateID>" +
          "  </e:property>" +
          "</e:propertyset>"
        
        guard let props = try UPnPEventProperties.read(xmlString: propertyXml) else {
            XCTAssert(false)
            return
        }
        helperTestProperties(props: props)

        // --
        
        guard let props2 = try UPnPEventProperties.read(xmlString: props.xmlDocument) else {
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
    func testDeviceDescription() throws {

        do {
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
              "  <UDN>uuid:e399855c-7ecb-1fff-8000-000000000000</UDN>" +
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
            
            guard let device = try UPnPDevice.read(xmlString: deviceDescription) else {
                XCTAssert(false)
                return
            }
            
            XCTAssertEqual("UPnP Sample Dimmable Light ver.1", device.friendlyName)

            XCTAssertTrue(device.embeddedDevices.isEmpty)
        }



        do {
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
              "  <UDN>uuid:e399855c-7ecb-1fff-8000-000000000000</UDN>" +

              "<iconList>" +
              "<icon>" +
              "<mimetype>image/png</mimetype>" +
              "<width>100</width>" +
              "<height>80</height>" +
              "<depth>4</depth>" +
              "<url>http://example.com/icon</url>" +
              "</icon>" +
              "</iconList>" +
              
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

              "<deviceList>" +
              "<device>" +
              "  <deviceType>urn:schemas-upnp-org:device:Basic:1</deviceType>" +
              "  <friendlyName>UPnP Basic Device</friendlyName>" +
              "  <manufacturer>Testers</manufacturer>" +
              "  <manufacturerURL>www.example.com</manufacturerURL>" +
              "  <modelDescription>UPnP Test Device</modelDescription>" +
              "  <modelName>UPnP Test Device</modelName>" +
              "  <modelNumber>2</modelNumber>" +
              "  <modelURL>www.example.com</modelURL>" +
              "  <serialNumber>abcd12345678</serialNumber>" +
              "  <UDN>uuid:e399855c-7ecb-1fff-8000-000000000000</UDN>" +
              "</device>" +
              "</deviceList>" +
              
              "  </device>" +
              "</root>"
            
            guard let device = try UPnPDevice.read(xmlString: deviceDescription) else {
                XCTAssert(false)
                return
            }

            XCTAssertTrue(device.isRootDevice)
            XCTAssertTrue(device === device.rootDevice)
            
            XCTAssertEqual("UPnP Sample Dimmable Light ver.1", device.friendlyName)

            XCTAssertEqual(device.icons.count, 1)
            XCTAssertEqual(device.icons[0].mimeType, "image/png")
            XCTAssertEqual(device.icons[0].widthString, "100")
            XCTAssertEqual(device.icons[0].heightString, "80")
            XCTAssertEqual(device.icons[0].width, 100)
            XCTAssertEqual(device.icons[0].height, 80)
            XCTAssertEqual(device.icons[0].url, "http://example.com/icon")

            XCTAssertFalse(device.embeddedDevices.isEmpty)
            XCTAssertEqual(device.embeddedDevices.count, 1)

            let basicDevice = device.embeddedDevices[0]

            XCTAssertFalse(basicDevice.isRootDevice)
            XCTAssertTrue(device === basicDevice.rootDevice)
            
            XCTAssertEqual("UPnP Basic Device", basicDevice.friendlyName)
            XCTAssertTrue(basicDevice.services.isEmpty)

            basicDevice["x-key"] = "x-var"
            XCTAssertEqual("x-var", basicDevice["x-key"])
            basicDevice["x-key"] = nil
            XCTAssertNil(basicDevice["x-key"])

            if let usnList = device.allUsnList {
                usnList.forEach {
                    print($0.description)
                }
            }
        }
    }

    /**
     test action argument 
     */
    func testActionArgument() throws {

        do {
            let argumentXml = "  <argument>" +
              "    <name>GetLoadlevelTarget</name>" +
              "    <direction>out</direction>" +
              "    <relatedStateVariable>LoadLevelTarget</relatedStateVariable>" +
              "  </argument>"

            let doc = try XmlParser.parse(xmlString: argumentXml)
            guard let root = doc.rootElement else {
                XCTFail("parsing xml error")
                return
            }
            
            guard let argument = UPnPActionArgument.read(xmlElement: root) else {
                XCTFail("UPnPActionArgument.read failed")
                return
            }
            XCTAssertEqual(argument.name, "GetLoadlevelTarget")
            XCTAssertEqual(argument.direction, UPnPActionArgumentDirection.output)
            argument.direction = UPnPActionArgumentDirection.input
            XCTAssertEqual(argument.direction, UPnPActionArgumentDirection.input)
            XCTAssertEqual(argument.relatedStateVariable, "LoadLevelTarget")
        }

        do {
            let argumentXml = "  <argument>" +
              "    <name>GetLoadlevelTarget</name>" +
              "    <direction>out</direction>" +
              "    <relatedStateVariable>LoadLevelTarget</relatedStateVariable>" +
              "  </argument>"

            guard let argument = try UPnPActionArgument.read(xmlString: argumentXml) else {
                XCTFail("UPnPActionArgument.read failed")
                return
            }
            XCTAssertEqual(argument.name, "GetLoadlevelTarget")
            XCTAssertEqual(argument.direction, UPnPActionArgumentDirection.output)
            argument.direction = UPnPActionArgumentDirection.input
            XCTAssertEqual(argument.direction, UPnPActionArgumentDirection.input)
            XCTAssertEqual(argument.relatedStateVariable, "LoadLevelTarget")
        }

        do {
            let argumentXml = "  <argument>" +
              "    <name>GetLoadlevelTarget</name>" +
              "  </argument>"

            guard let argument = try UPnPActionArgument.read(xmlString: argumentXml) else {
                XCTFail("UPnPActionArgument.read failed")
                return
            }
            XCTAssertEqual(argument.name, "GetLoadlevelTarget")
            XCTAssertNil(argument.direction)
            argument.direction = UPnPActionArgumentDirection.input
            XCTAssertEqual(argument.direction, UPnPActionArgumentDirection.input)
            XCTAssertNil(argument.relatedStateVariable)
        }

        do {
            let argumentXml = "  <argument>" +
              "    <name></name>" +
              "  </argument>"

            guard let argument = try UPnPActionArgument.read(xmlString: argumentXml) else {
                XCTFail("UPnPActionArgument.read failed")
                return
            }
            XCTAssertEqual("", argument.name)
            XCTAssertNil(argument.direction)
            XCTAssertNil(argument.relatedStateVariable)
        }

        do {
            let argumentXml = "  <argument>" +
              "    <name></name>" +
              "    <x-ext></x-ext>" +
              "    <x-ext2 />" +
              "  </argument>"

            guard let argument = try UPnPActionArgument.read(xmlString: argumentXml) else {
                XCTFail("UPnPActionArgument.read failed")
                return
            }
            XCTAssertEqual("", argument.name)
            XCTAssertNil(argument.direction)
            XCTAssertNil(argument.relatedStateVariable)
            XCTAssertNotNil(argument["x-ext"])
            XCTAssertTrue(argument["x-ext"]?.isEmpty ?? false)
            XCTAssertNotNil(argument["x-ext2"])
            XCTAssertTrue(argument["x-ext2"]?.isEmpty ?? false)
            XCTAssertNil(argument["noname"])
        }
    }

    /**
     test action
     */
    func testAction() throws {
        let actionRequest = UPnPActionRequest(actionName: "aBc")
        XCTAssertEqual(actionRequest.actionName, "aBc")

        do {
            
            let actionXml = " <action>" +
              "   <name>SetLoadLevelTarget</name>" +
              "   <argumentList>" +
              "  <argument>" +
              "    <name>newLoadlevelTarget</name>" +
              "    <direction>in</direction>" +
              "    <relatedStateVariable>LoadLevelTarget</relatedStateVariable>" +
              "  </argument>" +
              "   </argumentList>" +
              " </action>"

            guard let action = try UPnPAction.read(xmlString: actionXml) else {
                XCTFail("upnpaction read failed")
                return
            }

            XCTAssertEqual("SetLoadLevelTarget", action.name)

            guard let name = action.arguments[0].name else {
                XCTFail("action.arguments[0].name is nil")
                return
            }

            XCTAssertEqual("newLoadlevelTarget", name)

        }

        do {
            
            let actionXml = """
              <action>
                 <name>SetLoadLevelTarget</name>
                 <argumentList>
                 </argumentList>
               </action>
              """

            guard let action = try UPnPAction.read(xmlString: actionXml) else {
                XCTFail("upnpaction read failed")
                return
            }

            XCTAssertEqual("SetLoadLevelTarget", action.name)

            XCTAssertTrue(action.arguments.isEmpty)
        }

        do {
            
            let actionXml = """
              <action>
                 <name>SetLoadLevelTarget</name>
               </action>
              """

            guard let action = try UPnPAction.read(xmlString: actionXml) else {
                XCTFail("upnpaction read failed")
                return
            }

            XCTAssertEqual("SetLoadLevelTarget", action.name)

            XCTAssertTrue(action.arguments.isEmpty)
        }

        do {
            
            let actionXml = """
              <action>
                 <name></name>
               </action>
              """

            guard let action = try UPnPAction.read(xmlString: actionXml) else {
                XCTFail("upnpaction read failed")
                return
            }

            XCTAssertEqual("", action.name)

            XCTAssertTrue(action.arguments.isEmpty)
        }

        do {
            
            let actionXml = """
              <action>
                 <name>anyname</name>
                 <x-ext />
               </action>
              """

            guard let action = try UPnPAction.read(xmlString: actionXml) else {
                XCTFail("upnpaction read failed")
                return
            }

            XCTAssertEqual("anyname", action.name)
            XCTAssertNotNil(action["x-ext"])
            XCTAssertNil(action["noitem"])

            XCTAssertTrue(action.arguments.isEmpty)
        }

        do {
            
            let actionXml = """
              <action>
                 <name>anyname</name>
                 <x-ext></ x-ext>
               </action>
              """

            guard let action = try UPnPAction.read(xmlString: actionXml) else {
                XCTFail("upnpaction read failed")
                return
            }

            XCTAssertEqual("anyname", action.name)
            XCTAssertNotNil(action["x-ext"])
            XCTAssertNil(action["noitem"])

            XCTAssertTrue(action.arguments.isEmpty)
        }
        
    }

    /**
     test scpd
     */
    func testScpd() throws {

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
        
        guard let scpd = try UPnPScpd.read(xmlString: scpd_xml) else {
            XCTAssert(false)
            return
        }

        XCTAssertEqual("SetLoadLevelTarget", scpd.actions[0].name!)
        XCTAssertEqual("GetLoadLevelTarget", scpd.actions[1].name!)
        XCTAssertEqual("GetLoadLevelStatus", scpd.actions[2].name!)
        XCTAssertEqual("LoadLevelTarget", scpd.stateVariables[0].name!)
        XCTAssertEqual("LoadLevelStatus", scpd.stateVariables[1].name!)

        XCTAssertEqual("LoadLevelTarget", scpd.stateVariables[0].name!)
        XCTAssertEqual("ui1", scpd.stateVariables[0].dataType!)
        XCTAssertEqual("LoadLevelStatus", scpd.stateVariables[1].name!)
        XCTAssertEqual("ui1", scpd.stateVariables[1].dataType!)
    }

    /**
     test state variable
     */
    func testStateVariable() throws {

        if let elem = try XmlParser.parse(xmlString: "<stateVariable sendEvents=\"no\">" +
                                             "<name>LoadLevelTarget</name>" +
                                             "<dataType>ui1</dataType>" +
                                             "</stateVariable>").rootElement {
            let stateVariable = UPnPStateVariable.read(xmlElement: elem)

            XCTAssertEqual("LoadLevelTarget", stateVariable.name)
            XCTAssertEqual("ui1", stateVariable.dataType)
            XCTAssertEqual(false, stateVariable.sendEvents)
            XCTAssertNil(stateVariable.multicast)

            XCTAssertEqual("<stateVariable sendEvents=\"no\">" +
                             "<name>LoadLevelTarget</name>" +
                             "<dataType>ui1</dataType>" +
                             "</stateVariable>", stateVariable.description)
        }

        if let elem = try XmlParser.parse(xmlString: "<stateVariable sendEvents=\"yes\" multicast=\"no\">" +
                                             "<name>LoadLevelTarget</name>" +
                                             "<dataType>ui1</dataType>" +
                                             "</stateVariable>").rootElement {
            let stateVariable = UPnPStateVariable.read(xmlElement: elem)

            XCTAssertEqual("LoadLevelTarget", stateVariable.name)
            XCTAssertEqual("ui1", stateVariable.dataType)
            XCTAssertEqual(true, stateVariable.sendEvents)
            XCTAssertEqual(false, stateVariable.multicast)
            XCTAssertEqual("<stateVariable sendEvents=\"yes\" multicast=\"no\">" +
                             "<name>LoadLevelTarget</name>" +
                             "<dataType>ui1</dataType>" +
                             "</stateVariable>", stateVariable.description)
        }

        if let elem = try XmlParser.parse(xmlString: "<stateVariable multicast=\"yes\">" +
                                             "<name>LoadLevelTarget</name>" +
                                             "<dataType>ui1</dataType>" +
                                             "<defaultValue>12</defaultValue>" +
                                             "</stateVariable>").rootElement {
            let stateVariable = UPnPStateVariable.read(xmlElement: elem)

            XCTAssertEqual("LoadLevelTarget", stateVariable.name)
            XCTAssertEqual("ui1", stateVariable.dataType)
            XCTAssertNil(stateVariable.sendEvents)
            XCTAssertEqual(true, stateVariable.multicast)
            XCTAssertEqual("12", stateVariable.defaultValue)
            XCTAssertEqual("<stateVariable multicast=\"yes\">" +
                             "<name>LoadLevelTarget</name>" +
                             "<dataType>ui1</dataType>" +
                             "<defaultValue>12</defaultValue>" +
                             "</stateVariable>", stateVariable.description)
        }

        if let elem = try XmlParser.parse(xmlString: "<stateVariable multicast=\"yes\">" +
                                             "<name>LoadLevelTarget</name>" +
                                             "<dataType>ui1</dataType>" +
                                             "<defaultValue>12</defaultValue>" +
                                             "<allowedValueRange><minimum>10</minimum><maximum>15</maximum></allowedValueRange>" +
                                             "</stateVariable>").rootElement {
            let stateVariable = UPnPStateVariable.read(xmlElement: elem)

            XCTAssertEqual("LoadLevelTarget", stateVariable.name)
            XCTAssertEqual("ui1", stateVariable.dataType)
            XCTAssertNil(stateVariable.sendEvents)
            XCTAssertEqual(true, stateVariable.multicast)
            XCTAssertEqual("12", stateVariable.defaultValue)
            XCTAssertEqual("10", stateVariable.allowedValueRange?.minimum)
            XCTAssertEqual("15", stateVariable.allowedValueRange?.maximum)
            XCTAssertEqual("<stateVariable multicast=\"yes\">" +
                             "<name>LoadLevelTarget</name>" +
                             "<dataType>ui1</dataType>" +
                             "<defaultValue>12</defaultValue>" +
                             "<allowedValueRange><minimum>10</minimum><maximum>15</maximum></allowedValueRange>" +
                             "</stateVariable>", stateVariable.description)
        }

        if let elem = try XmlParser.parse(xmlString: "<stateVariable multicast=\"yes\">" +
                                             "<name>LoadLevelTarget</name>" +
                                             "<dataType>ui1</dataType>" +
                                             "<defaultValue>12</defaultValue>" +
                                             "<allowedValueList><allowedValue>12</allowedValue><allowedValue>14</allowedValue><allowedValue>16</allowedValue></allowedValueList>" +
                                             "</stateVariable>").rootElement {
            let stateVariable = UPnPStateVariable.read(xmlElement: elem)

            XCTAssertEqual("LoadLevelTarget", stateVariable.name)
            XCTAssertEqual("ui1", stateVariable.dataType)
            XCTAssertNil(stateVariable.sendEvents)
            XCTAssertEqual(true, stateVariable.multicast)
            XCTAssertEqual("12", stateVariable.defaultValue)
            XCTAssertEqual(["12", "14", "16"], stateVariable.allowedValueList?.items)
            XCTAssertEqual("<stateVariable multicast=\"yes\">" +
                             "<name>LoadLevelTarget</name>" +
                             "<dataType>ui1</dataType>" +
                             "<defaultValue>12</defaultValue>" +
                             "<allowedValueList><allowedValue>12</allowedValue><allowedValue>14</allowedValue><allowedValue>16</allowedValue></allowedValueList>" +
                             "</stateVariable>", stateVariable.description)
        }
    }

    /**
     test soap
     */
    func testSoap() throws {

        do {
            let soapRequest = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" +
              "<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"" +
              "      xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">" +
              "  <s:Body>" +
              "  <u:SetTarget xmlns:u=\"urn:schemas-upnp-org:service:SwitchPower:1\">" +
              "  </u:SetTarget>" +
              "  </s:Body>" +
              "</s:Envelope>"
            
            guard let request = try UPnPSoapRequest.read(xmlString: soapRequest) else {
                XCTAssert(false)
                return
            }
            XCTAssertEqual("urn:schemas-upnp-org:service:SwitchPower:1#SetTarget", request.soapaction)
            XCTAssertEqual("SetTarget", request.actionName)
            XCTAssertTrue(request.keys.isEmpty)
            XCTAssertNil(request["newTargetValue"])
        }

        let soapRequest = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" +
          "<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"" +
          "      xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">" +
          "  <s:Body>" +
          "  <u:SetTarget xmlns:u=\"urn:schemas-upnp-org:service:SwitchPower:1\">" +
          "    <newTargetValue>10</newTargetValue>" +
          "  </u:SetTarget>" +
          "  </s:Body>" +
          "</s:Envelope>"
        
        guard let request = try UPnPSoapRequest.read(xmlString: soapRequest) else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual("urn:schemas-upnp-org:service:SwitchPower:1#SetTarget", request.soapaction)
        XCTAssertEqual("SetTarget", request.actionName)
        XCTAssertEqual(["newTargetValue"], request.keys)
        XCTAssertNotNil(request["newTargetValue"])
        XCTAssertEqual("10", request["newTargetValue"])

        // --

        let soapResponse = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
          "<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">" +
          "  <s:Body>" +
          "  <u:BrowseResponse xmlns:u=\"urn:schemas-upnp-org:service:ContentDirectory:1\">" +
          "    <Result>&lt;DIDL-Lite xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:upnp=\"urn:schemas-upnp-org:metadata-1-0/upnp/\" xmlns:dlna=\"urn:schemas-dlna-org:metadata-1-0/\"&gt;&lt;container id=\"94467912-bd40-4d2f-ad25-7b8423f7b05a\" parentID=\"0\" restricted=\"1\" searchable=\"0\"&gt;&lt;dc:title&gt;Video&lt;/dc:title&gt;&lt;dc:creator&gt;Unknown&lt;/dc:creator&gt;&lt;upnp:genre&gt;Unknown&lt;/upnp:genre&gt;&lt;dc:description&gt;Video&lt;/dc:description&gt;&lt;upnp:class&gt;object.container.storageFolder&lt;/upnp:class&gt;&lt;/container&gt;&lt;container id=\"abe6121c-1731-4683-815c-89e1dcd2bf11\" parentID=\"0\" restricted=\"1\" searchable=\"0\"&gt;&lt;dc:title&gt;Music&lt;/dc:title&gt;&lt;dc:creator&gt;Unknown&lt;/dc:creator&gt;&lt;upnp:genre&gt;Unknown&lt;/upnp:genre&gt;&lt;dc:description&gt;Music&lt;/dc:description&gt;&lt;upnp:class&gt;object.container.storageFolder&lt;/upnp:class&gt;&lt;/container&gt;&lt;container id=\"b0184133-f840-4a4f-a583-45f99645edcd\" parentID=\"0\" restricted=\"1\" searchable=\"0\"&gt;&lt;dc:title&gt;Photos&lt;/dc:title&gt;&lt;dc:creator&gt;Unknown&lt;/dc:creator&gt;&lt;upnp:genre&gt;Unknown&lt;/upnp:genre&gt;&lt;dc:description&gt;Photos&lt;/dc:description&gt;&lt;upnp:class&gt;object.container.storageFolder&lt;/upnp:class&gt;&lt;/container&gt;&lt;/DIDL-Lite&gt;</Result>" +
          "  <NumberReturned>3</NumberReturned><TotalMatches>3</TotalMatches><UpdateID>76229067</UpdateID></u:BrowseResponse>" +
          "  </s:Body>" +
          "</s:Envelope>"
        
        guard let response = try UPnPSoapResponse.read(xmlString: soapResponse) else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual("urn:schemas-upnp-org:service:ContentDirectory:1", response.serviceType)
        XCTAssertEqual("Browse", response.actionName)
    }

    func testSoapError() throws {

        let soapErrorResponse = "<?xml version=\"1.0\"?>" +
          "<s:Envelope " +
          "xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" " +
          "s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">" +
          "<s:Body>" +
          "<s:Fault>" +
          "<faultcode>s:Client</faultcode>" +
          "<faultstring>UPnPError</faultstring>" +
          "<detail>" +
          "<UPnPError xmlns=\"urn:schemas-upnp-org:control-1-0\">" +
          "<errorCode>401</errorCode>" +
          "<errorDescription>Invalid Action</errorDescription>" +
          "</UPnPError>" +
          "</detail>" +
          "</s:Fault>" +
          "</s:Body>" +
          "</s:Envelope>"

        let response = try UPnPSoapErrorResponse.read(xmlString: soapErrorResponse)

        XCTAssertEqual(401, response.errorCode)
        XCTAssertEqual("Invalid Action", response.errorDescription)


        let xml = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n" +
          "<s:Envelope " +
          "xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" " +
          "s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">" +
          "<s:Body>" +
          "<s:Fault>" +
          "<faultcode>s:Client</faultcode>" +
          "<faultstring>UPnPError</faultstring>" +
          "<detail>" +
          "<UPnPError xmlns=\"urn:schemas-upnp-org:control-1-0\">" +
          "<errorCode>600</errorCode>" +
          "<errorDescription>Argument Value Invalid</errorDescription>" +
          "</UPnPError>" +
          "</detail>" +
          "</s:Fault>" +
          "</s:Body>" +
          "</s:Envelope>"

        let description = "<s:Envelope " +
          "xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" " +
          "s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">" +
          "<s:Body>" +
          "<s:Fault>" +
          "<faultcode>s:Client</faultcode>" +
          "<faultstring>UPnPError</faultstring>" +
          "<detail>" +
          "<UPnPError xmlns=\"urn:schemas-upnp-org:control-1-0\">" +
          "<errorCode>600</errorCode>" +
          "<errorDescription>Argument Value Invalid</errorDescription>" +
          "</UPnPError>" +
          "</detail>" +
          "</s:Fault>" +
          "</s:Body>" +
          "</s:Envelope>"

        let resp = try UPnPSoapErrorResponse.read(xmlString: xml)

        XCTAssertEqual(600, resp.errorCode)
        XCTAssertEqual("Argument Value Invalid", resp.errorDescription)

        XCTAssertEqual(description.lowercased(), resp.description.lowercased())
        XCTAssertEqual(description, resp.description)
        XCTAssertEqual(xml.lowercased(), resp.xmlDocument.lowercased())
        XCTAssertEqual(xml, resp.xmlDocument)
    }
    

    /**
     test servcie
     */
    func testService() throws {

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
        
        guard let scpd = try UPnPScpd.read(xmlString: scpd_xml) else {
            XCTAssert(false)
            return
        }

        let service = UPnPService()
        service.scpd = scpd
        service.scpdUrl = "/scpd.xml"

        let device = UPnPDevice()
        device.baseUrl = URL(string: "http://example.com")
        XCTAssertTrue(device.isRootDevice)
        XCTAssertTrue(device === device.rootDevice)

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
     all tests
     */
    static var allTests = [
      ("testProperty", testProperty),
      ("testUPnPModel", testUPnPModel),
      ("testUsn", testUsn),
      ("testXml", testXml),
      ("testDeviceDescription", testDeviceDescription),
      ("testService", testService),
      ("testStateVariable", testStateVariable),
      ("testSoap", testSoap),
      ("testSoapError", testSoapError),
      ("testActionArgument", testActionArgument),
      ("testAction", testAction),
      ("testScpd", testScpd),
      
    ]


    
}
