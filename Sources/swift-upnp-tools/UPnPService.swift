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
    
    public var controlUrl: String? {
        get { return self["controlURL"] }
        set(value) { self["controlURL"] = value }
    }
    
    public var eventSubUrl: String? {
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
