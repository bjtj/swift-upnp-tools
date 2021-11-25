import Foundation
import SwiftUpnpTools

func main() {

    print(" --=== UPnP Server ===--")

    let server = startServer(port: 9999)

    server.onActionRequest {
        (service, soapRequest) in
        let properties = OrderedProperties()
        properties["GetLoadlevelTarget"] = "10"
        return properties
    }

    var done = false

    while !done {
        guard let line = readLine() else {
            continue
        }

        switch line {
        case "quit", "q":
            done = true
            break;
        default:
            break;
        }
    }

    print(" --=== DONE ===--")

    server.finish()
}


func startServer(port: Int) -> UPnPServer {
    let server = UPnPServer(httpServerBindPort: port)
    server.run()
    registerDevice(server: server)
    return server
}

func registerDevice(server: UPnPServer) {
    guard let device = UPnPDevice.read(xmlString: deviceDescription_DimmableLight) else {
        print("UPnPDevice read failed")
        return
    }

    guard let service = device.getService(type: "urn:schemas-upnp-org:service:SwitchPower:1") else {
        print("No Service (urn:schemas-upnp-org:service:SwitchPower:1)")
        return
    }
    service.scpd = UPnPScpd.read(xmlString: scpd_SwitchPower)
    
    server.registerDevice(device: device)
}

var deviceDescription_DimmableLight = "<?xml version=\"1.0\"?>" +
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


var scpd_SwitchPower = "<?xml version=\"1.0\"?>" +
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

main()