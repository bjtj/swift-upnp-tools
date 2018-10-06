import Foundation
import SwiftXml


public class UPnPService : UPnPModel {

    public var device: UPnPDevice?
    public var scpd: UPnPScpd?
    
    public var serviceId: String? {
        get { return self["serviceId"] }
        set(value) { self["serviceId"] = value }
    }
    
    public var serviceType: String? {
        get { return self["serviceType"] }
        set(value) { self["serviceType"] = value }
    }
    
    public var scpdUrl: String? {
        get { return self["SCPDURL"] }
        set(value) { self["SCPDURL"] = value }
    }

    public var scpdUrlFull: URL? {
        guard let scpdUrl = scpdUrl else {
            return nil
        }
        return fullUrl(relativeUrl: scpdUrl)
    }
    
    public var controlUrl: String? {
        get { return self["controlURL"] }
        set(value) { self["controlURL"] = value }
    }

    public var controlUrlFull: URL? {
        guard let controlUrl = controlUrl else {
            return nil
        }
        return fullUrl(relativeUrl: controlUrl)
    }
    
    public var eventSubUrl: String? {
        get { return self["eventSubURL"] }
        set(value) { self["eventSubURL"] = value }
    }
    
    public var eventSubUrlFull: URL? {
        guard let eventSubUrl = eventSubUrl else {
            return nil
        }
        return fullUrl(relativeUrl: eventSubUrl)
    }

    public func fullUrl(relativeUrl: String) -> URL? {
        guard let device = device else {
            print("no device")
            return nil
        }
        return URL(string: relativeUrl, relativeTo: device.rootDevice.baseUrl)
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

    public var usn: UPnPUsn? {
        guard let device = device, let serviceType = serviceType else {
            return nil
        }
        guard let udn = device.udn else {
            return nil
        }
        return UPnPUsn(uuid: udn, type: serviceType)
    }
}
