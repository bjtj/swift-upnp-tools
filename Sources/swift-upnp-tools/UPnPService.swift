//
// UPnPService.swift
// 

import Foundation
import SwiftXml

/**
 UPnP Service (Model)
 */
public class UPnPService : UPnPModel {

    /**
     Service Building Status
     */
    public enum Status {
        case idle, progress, failed, completed
    }

    /**
     UPnP Device
     */
    public var device: UPnPDevice?
    /**
     UPnP Scpd
     */
    public var scpd: UPnPScpd?
    /**
     build status
     */
    public var status: Status
    /**
     error string
     */
    public var error: Error?

    /**
     service id
     */
    public var serviceId: String? {
        get { return self["serviceId"] }
        set(value) { self["serviceId"] = value }
    }

    /**
     service type
     */
    public var serviceType: String? {
        get { return self["serviceType"] }
        set(value) { self["serviceType"] = value }
    }

    /**
     scpd url (raw)
     */
    public var scpdUrl: String? {
        get { return self["SCPDURL"] }
        set(value) { self["SCPDURL"] = value }
    }

    /**
     scpd url (full url)
     */
    public var scpdUrlFull: URL? {
        guard let scpdUrl = scpdUrl else {
            return nil
        }
        return fullUrl(relativeUrl: scpdUrl)
    }

    /**
     control url (raw)
     */
    public var controlUrl: String? {
        get { return self["controlURL"] }
        set(value) { self["controlURL"] = value }
    }

    /**
     control ful (full url)
     */
    public var controlUrlFull: URL? {
        guard let controlUrl = controlUrl else {
            return nil
        }
        return fullUrl(relativeUrl: controlUrl)
    }

    /**
     event sub url (raw)
     */
    public var eventSubUrl: String? {
        get { return self["eventSubURL"] }
        set(value) { self["eventSubURL"] = value }
    }
    
    /**
     event sub url (full url)
     */
    public var eventSubUrlFull: URL? {
        guard let eventSubUrl = eventSubUrl else {
            return nil
        }
        return fullUrl(relativeUrl: eventSubUrl)
    }

    public override init() {
        status = .idle
    }

    /**
     get full url (base url + relative url)
     */
    public func fullUrl(relativeUrl: String) -> URL? {
        guard let device = device else {
            return nil
        }
        return URL(string: relativeUrl, relativeTo: device.rootDevice.baseUrl)
    }

    /**
     read from xml element
     */
    public static func read(xmlElement: XmlElement) -> UPnPService {
        let service = UPnPService()
        guard let elements = xmlElement.elements else {
            return service
        }
        for element in elements {

            let (_name, value) = readNameValue(element: element)
            guard let name = _name else {
                continue
            }
            service[name] = value ?? ""
        }
        return service
    }

    public var description: String {
        return XmlTag(name: "service", content: propertyXml).description
    }

    /**
     usn
     */
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
