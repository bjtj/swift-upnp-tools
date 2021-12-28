//
// UPnPDevice.swift
// 

import Foundation
import SwiftXml

/**
 UPnP Device Model
 */
public class UPnPDevice : UPnPTimeBasedModel {

    /**
     Device Status
     */
    public enum Status {
        case unknown, recognized, building, incompleted, completed
    }
    
    /**
     Status
     */
    public var status: Status = .unknown
    
    /**
     Parent Device
     */
    public var parent: UPnPDevice?
    /**
     Base Url
     */
    public var baseUrl: URL?
    /**
     Services
     */
    public var services = [UPnPService]()
    /**
     Embedded Devices
     */
    public var embeddedDevices = [UPnPDevice]()
    /**
     Icons
     */
    public var icons = [UPnPIcon]()
    

    override public init(timeout: UInt64 = 1800) {
        super.init(timeout: timeout)
    }

    /**
     UDN
     */
    public var udn: String? {
        get { return self["UDN"] }
        set(value) { self["UDN"] = value }
    }

    /**
     Friendly Name
     */
    public var friendlyName: String? {
        get { return self["friendlyName"] }
        set(value) { self["friendlyName"] = value }
    }

    /**
     Device Type
     */
    public var deviceType: String? {
        get { return self["deviceType"] }
        set(value) { self["deviceType"] = value }
    }

    /**
     Get Root Device
     */
    public var rootDevice: UPnPDevice {

        guard let parent = parent else {
            return self
        }
        return parent.rootDevice
    }

    /**
     Test if it is root device
     */
    public var isRootDevice: Bool {
        return parent == nil
    }

    /**
     Get all service types
     */
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

    /**
     All services
     */
    public var allServices: [UPnPService] {
        var services = [UPnPService]()
        services += self.services
        for device in embeddedDevices {
            services += device.allServices
        }
        return services
    }
    
    /**
     Building service count
     */
    public var buildingServiceCount: Int = 0
    
    /**
     Building service error count
     */
    public var buildingServiceErrorCount: Int = 0

    /**
     Get device with type
     */
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

    /**
     Get service with type
     */
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

    /**
     Get service with scpd url
     */
    public func getService(withScpdUrl scpdUrl: String) -> UPnPService? {
        for service in services {
            guard let url = service.scpdUrl else {
                continue
            }
            if url == scpdUrl {
                return service
            }
        }

        for device in embeddedDevices {
            if let service = device.getService(withScpdUrl: scpdUrl) {
                return service
            }
        }
        
        return nil
    }

    /**
     Get service with control url
     */
    public func getService(withControlUrl controlUrl: String) -> UPnPService? {
        for service in services {
            guard let url = service.controlUrl else {
                continue
            }
            if url == controlUrl {
                return service
            }
        }

        for device in embeddedDevices {
            if let service = device.getService(withScpdUrl: controlUrl) {
                return service
            }
        }
        
        return nil
    }

    /**
     Get service with event sub url
     */
    public func getService(withEventSubUrl eventSubUrl: String) -> UPnPService? {
        for service in services {
            guard let url = service.eventSubUrl else {
                continue
            }
            if url == eventSubUrl {
                return service
            }
        }

        for device in embeddedDevices {
            if let service = device.getService(withScpdUrl: eventSubUrl) {
                return service
            }
        }
        
        return nil
    }

    /**
     Add embedded device
     */
    public func addEmbeddedDevice(device: UPnPDevice) {
        device.parent = self

        embeddedDevices.append(device)
    }

    /**
     Remove embedded device with index
     */
    public func removeEmbeddedDevice(at: Int) {
        embeddedDevices.remove(at: at)
    }

    /**
     Add service
     */
    public func addService(service: UPnPService) {
        service.device = self
        services.append(service)
    }

    /**
     Remove service with index
     */
    public func removeService(at: Int) {
        services.remove(at: at)
    }

    /**
     Remove service with type
     */
    public func removeService(serviceType: String) {
        services = services.filter { $0.serviceType != serviceType }
    }

    /**
     Read from xml string
     */
    public static func read(xmlString: String) throws -> UPnPDevice? {
        let document = try XmlParser.parse(xmlString: xmlString)
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

    /**
     Read from xml element
     */
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
            } else if element.name == "iconList" {
                if let iconElements = element.elements {
                    for iconElement in iconElements {
                        if iconElement.name == "icon", let icon = UPnPIcon.read(xmlElement: iconElement) {
                            device.icons.append(icon)
                        }
                    }
                }
            } else {
                let (_name, value) = readNameValue(element: element)
                guard let name = _name else {
                    continue
                }
                device[name] = value ?? ""
            }
        }
        return device
    }

    /**
     Get xml document
     */
    public var xmlDocument: String {
        let root = XmlTag(name: "root", ext: "xmlns=\"urn:schemas-upnp-org:device-1-0\"", content: description)
        return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n\(root.description)"
    }

    public var description: String {
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
