import Foundation
import SwiftXml

public class UPnPModel : OrderedProperties {
    public var propertyXml: String {
        var str = ""
        for field in fields {
            str += XmlTag(name: field.key, text: field.value).description
        }
        return str
    }
}


public class UPnPSpecVersion : UPnPModel {
    public var major: String? {
        get { return self["major"] }
        set(value) { self["major"] = value }
    }
    public var minor: String? {
        get { return self["minor"] }
        set(value) { self["minor"] = value }
    }
    public init(major: Int = 1, minor: Int = 0) {
        super.init()
        self["major"] = "\(major)"
        self["minor"] = "\(minor)"
    }

    public static func read(xmlElement: XmlElement) -> UPnPSpecVersion? {
        guard let elements = xmlElement.elements else {
            return nil
        }

        let version = UPnPSpecVersion()
        for element in elements {
            if element.name == "major" {
                if let firstText = element.firstText {
                    version.major = firstText.text
                }
            } else if element.name == "minor" {
                if let firstText = element.firstText {
                    version.minor = firstText.text
                }
            }
        }
        return version
    }
    
    public var description: String {
        var str = ""
        if let major = major {
            str += XmlTag(name: "major", text: major).description
        }
        if let minor = minor {
            str += XmlTag(name: "minor", text: minor).description
        }
        return XmlTag(name: "specVersion", content: str).description
    }
}


public class UPnPDevice : UPnPModel {
    public var parent: UPnPDevice?
    var timeBase: TimeBase
    public var baseUrl: URL?
    public var services = [UPnPService]()
    public var embeddedDevices = [UPnPDevice]()
    public var udn: String? {
        get { return self["UDN"] }
        set(value) { self["UDN"] = value }
    }
    
    public var friendlyName: String? {
        get { return self["friendlyName"] }
        set(value) { self["friendlyName"] = value }
    }

    public var deviceType: String? {
        get { return self["deviceType"] }
        set(value) { self["deviceType"] = value }
    }

    public var rootDevice: UPnPDevice {
        if parent == nil {
            return self
        }
        return parent!.rootDevice
    }
    
    public var isRootDevice: Bool {
        return parent == nil
    }

    public init(timeout: UInt64 = 1800) {
        self.timeBase = TimeBase(timeout: timeout)
    }

    public func renewTimeout() {
        timeBase.renewTimeout()
    }

    public var isExpired: Bool {
        return timeBase.isExpired
    }

    public var allServiceTypes: [UPnPUsn]? {
        var types = [UPnPUsn]()
        guard let udn = udn else {
            return nil
        }
        if let deviceType = deviceType {
            types.append(UPnPUsn(uuid: udn, type: deviceType))
        }
        for service in services {
            if let serviceType = service.serviceType {
                types.append(UPnPUsn(uuid: udn, type: serviceType))
            }
        }
        for embeddedDevice in embeddedDevices {
            if let serviceTypes = embeddedDevice.allServiceTypes {
                types += serviceTypes
            }
        }
        return types
    }

    public var allServices: [UPnPService] {
        var services = [UPnPService]()
        services += self.services
        for device in embeddedDevices {
            services += device.allServices
        }
        return services
    }

    public func getDevice(type: String) -> UPnPDevice? {
        if let deviceType = deviceType {
            if deviceType == type {
                return self
            }
        }
        
        for device in embeddedDevices {
            if let device = device.getDevice(type: type) {
                return device
            }
        }
        return nil
    }

    public func getService(type: String) -> UPnPService? {
        for service in services {
            guard let serviceType = service.serviceType else {
                continue
            }
            if serviceType == type {
                return service
            }
        }

        for device in embeddedDevices {
            if let service = device.getService(type: type) {
                return service
            }
        }
        
        return nil
    }
    
    public func addEmbeddedDevice(device: UPnPDevice) {
        device.parent = self

        embeddedDevices.append(device)
    }
    public func removeEmbeddedDevice(at: Int) {
        embeddedDevices.remove(at: at)
    }

    public func addService(service: UPnPService) {
        services.append(service)
    }

    public func removeService(at: Int) {
        services.remove(at: at)
    }

    public func removeService(serviceType: String) {
        services = services.filter { $0.serviceType != serviceType }
    }
    
    public static func read(xmlString: String) -> UPnPDevice? {
        let document = parseXml(xmlString: xmlString)
        guard let root = document.rootElement else {
            print("error -- no root element")
            return nil
        }
        guard let elements = root.elements else {
            print("error -- no elements in root")
            return nil
        }
        
        for element in elements {
            if element.name == "device" {
                return read(xmlElement: element)
            }
        }

        print("error -- no device")
        return nil
    }
    
    public static func read(xmlElement: XmlElement) -> UPnPDevice {
        let device = UPnPDevice()
        guard let elements = xmlElement.elements else {
            return device
        }
        for element in elements {
            if element.name == "deviceList" {
                if let deviceElements = element.elements {
                    for deviceElement in deviceElements {
                        if deviceElement.name == "device" {
                            device.addEmbeddedDevice(device: read(xmlElement: deviceElement))
                        }
                    }
                }
            } else if element.name == "serviceList" {
                if let serviceElements = element.elements {
                    for serviceElement in serviceElements {
                        if serviceElement.name == "service" {
                            device.addService(service: UPnPService.read(xmlElement: serviceElement))
                        }
                    }
                }
            } else if let firstText = element.firstText {
                if element.elements!.isEmpty {
                    device[element.name!] = firstText.text
                }
            }
        }
        return device
    }
    
    public var xmlDocument: String {
        let root = XmlTag(name: "root", ext: "xmlns=\"urn:schemas-upnp-org:device-1-0\"", content: description)
        return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n\(root.description)"
    }
    
    public var description: String {
        // let tag = XmlTag(name: "root", ext: "xmlns=\"urn:schemas-upnp-org:device-1-0\"", content: "")
        let tag = XmlTag(name: "device", content: "")
        var content = propertyXml
        
        if services.isEmpty == false {
            let serviceList = XmlTag(name: "serviceList", content: "")
            for service in services {
                serviceList.content += service.description
            }
            content += serviceList.description
        }
        if embeddedDevices.isEmpty == false {
            let deviceList = XmlTag(name: "deviceList", content: "")
            for device in embeddedDevices {
                deviceList.content += device.description
            }
            content += deviceList.description
        }
        tag.content = content
        return tag.description
    }
}

public class UPnPService : UPnPModel {

    public var scpd: UPnPScpd?

    
    public var serviceId: String? {
        get { return self["serviceId"] }
        set(value) { self["serviceId"] = value }
    }
    
    public var serviceType: String? {
        get { return self["serviceType"] }
        set(value) { self["serviceType"] = value }
    }
    
    public var spcdurl: String? {
        get { return self["SCPDURL"] }
        set(value) { self["SCPDURL"] = value }
    }
    
    public var controlUrl: String? {
        get { return self["controlURL"] }
        set(value) { self["controlURL"] = value }
    }
    
    public var evnetSubUrl: String? {
        get { return self["eventSubURL"] }
        set(value) { self["eventSubURL"] = value }
    }
    
    public static func read(xmlElement: XmlElement) -> UPnPService {
        let service = UPnPService()
        guard let elements = xmlElement.elements else {
            return service
        }
        for element in elements {
            if element.firstText != nil && element.elements!.isEmpty {
                service[element.name!] = element.firstText!.text
            }
        }
        return service
    }
    
    public var description: String {
        return XmlTag(name: "service", content: propertyXml).description
    }
}

public class UPnPScpd : UPnPModel {
    public var specVersion: UPnPSpecVersion?
    public var actions = [UPnPAction]()
    public var stateVariables = [UPnPStateVariable]()

    public static func read(xmlString: String) -> UPnPScpd? {
        let document = parseXml(xmlString: xmlString)
        guard let root = document.rootElement else {
            return nil
        }
        let scpd = UPnPScpd()
        guard let elements = root.elements else {
            return scpd
        }
        for element in elements {
            if element.name == "specVersion" {
                scpd.specVersion = UPnPSpecVersion.read(xmlElement: element)
            } else if element.name == "actionList" {
                scpd.actions = readActionList(xmlElement: element)
            } else if element.name == "serviceStateTable" {
                scpd.stateVariables = readStateVariables(xmlElement: element)
            }
        }
        return scpd
    }

    public static func readActionList(xmlElement: XmlElement) -> [UPnPAction] {
        var actions = [UPnPAction]()
        guard let elements = xmlElement.elements else {
            return actions
        }

        for element in elements {
            if element.name == "action" {
                let action = UPnPAction.read(xmlElement: element)
                actions.append(action)
            }
        }
        return actions
    }

    public static func readStateVariables(xmlElement: XmlElement) -> [UPnPStateVariable] {
        var stateVariables = [UPnPStateVariable]()
        guard let elements = xmlElement.elements else {
            return stateVariables
        }

        for element in elements {
            if element.name == "stateVariable" {
                let stateVariable = UPnPStateVariable.read(xmlElement: element)
                stateVariables.append(stateVariable)
            }
        }
        return stateVariables
    }

    public var xmlDocument: String {
        return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n\(self.description)"
    }

    public var description: String {
        let tag = XmlTag(name: "scpd", content: "")
        if let specVersion = specVersion {
            tag.content += specVersion.description
        }
        tag.content += actionListXml
        tag.content += serviceStateTableXml
        return tag.description
    }

    public var actionListXml: String {
        let tag = XmlTag(name: "actionList", content: "")
        for action in actions {
            tag.content += action.description
        }
        return tag.description
    }

    public var serviceStateTableXml: String {
        let tag = XmlTag(name: "serviceStateTable", content: "")
        for stateVariable in stateVariables {
            tag.content += stateVariable.description
        }
        return tag.description
    }
}

public class UPnPAction : UPnPModel {

    public var arguments = [UPnPActionArgument]()
    
    public var name: String? {
        get { return self["name"] }
        set(value) { self["name"] = value }
    }

    public static func read(xmlElement: XmlElement) -> UPnPAction {
        let action = UPnPAction()
        guard let elements = xmlElement.elements else {
            return action
        }
        for element in elements {
            if element.name == "argumentList" {
                let argument = UPnPActionArgument.read(xmlElement: element)
                action.arguments.append(argument)
            } else if element.firstText != nil && element.elements!.isEmpty {
                action[element.name!] = element.firstText!.text
            }
        }
        return action
    }

    public var description: String {
        let tag = XmlTag(name: "action", content: propertyXml)
        tag.content += argumentListXml
        return tag.description
    }

    public var argumentListXml: String {
        let tag = XmlTag(name: "argumentList", content: "")
        for argument in arguments {
            tag.content += argument.description
        }
        return tag.description
    }
}

public class UPnPActionArgument : UPnPModel {
    public var name: String? {
        get { return self["name"] }
        set(value) { self["name"] = value }
    }

    public static func read(xmlElement: XmlElement) -> UPnPActionArgument {
        let argument = UPnPActionArgument()
        guard let elements = xmlElement.elements else {
            return argument
        }
        for element in elements {
            if element.firstText != nil && element.elements!.isEmpty {
                argument[element.name!] = element.firstText!.text
            }
        }
        return argument
    }

    public var description: String {
        let tag = XmlTag(name: "argument", content: propertyXml)
        return tag.description
    }
}

public class UPnPStateVariable : UPnPModel {
    public var name: String? {
        get { return self["name"] }
        set(value) { self["name"] = value }
    }
    public var dataType: String? {
        get { return self["dataType"] }
        set(value) { self["dataType"] = value }
    }

    public static func read(xmlElement: XmlElement) -> UPnPStateVariable {
        let stateVariable = UPnPStateVariable()
        guard let elements = xmlElement.elements else {
            return stateVariable
        }
        for element in elements {
            if element.firstText != nil && element.elements!.isEmpty {
                stateVariable[element.name!] = element.firstText!.text
            }
        }
        return stateVariable
    }

    public var description: String {
        let tag = XmlTag(name: "stateVariable", content: propertyXml)
        return tag.description
    }
}

