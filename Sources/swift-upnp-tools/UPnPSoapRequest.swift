//
// UPnPSoapRequest.swift
// 

import SwiftXml

/**
 UPnP Soap Request
 */
public class UPnPSoapRequest : UPnPModel {

    /**
     service type
     */
    public var serviceType: String

    /**
     action name
     */
    public var actionName: String

    public var soapaction: String {
        return "\(serviceType)#\(actionName)"
    }

    public init(serviceType: String = "", actionName: String = "") {
        self.serviceType = serviceType
        self.actionName = actionName
    }

    /**
     read from xml string
     */
    public static func read(xmlString: String) -> UPnPSoapRequest? {
        let document = parseXml(xmlString: xmlString)
        guard let root = document.rootElement else {
            print("UPnPSoapRequest::read() error -- NO ROOT ELEMENT")
            return nil
        }
        guard let elements = root.elements, elements.isEmpty == false else {
            print("UPnPSoapRequest::read() error -- NO ELEMENTS")
            return nil
        }

        guard let name = elements[0].name, name == "Body" else {
            print("UPnPSoapRequest::read() error -- NO BODY TAG")
            return nil
        }

        guard let bodyElements = elements[0].elements, bodyElements.isEmpty == false else {
            print("UPnPSoapRequest::read() error -- empty actionElements")
            return nil
        }

        let actionElement = bodyElements[0]

        guard let actionName = actionElement.name else {
            print("UPnPSoapRequest::read() error -- no action name")
            return nil
        }

        let request = UPnPSoapRequest(actionName: actionName)
        guard let attributes = actionElement.attributes, attributes.isEmpty == false else {
            print("UPnPSoapRequest::read() error -- no service type")
            return nil
        }

        request.serviceType = "\(attributes[0].value ?? "")"

        if let propElements = actionElement.elements {
            for propElement in propElements {
                let (_name, value) = readNameValue(element: propElement)
                guard let name = _name else {
                    continue
                }
                request[name] = value ?? ""
            }
        }

        return request
    }

    /**
     get xml document
     */
    public var xmlDocument: String {
        return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n\(self.description)"
    }

    public var description: String {
        let ext = "s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" " +
          "xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\""
        let root = XmlTag(namespace: "s", name: "Envelope", ext: ext, content: "")
        let body = XmlTag(namespace: "s", name: "Body", content: "")
        let action = XmlTag(namespace: "u", name: actionName, ext: "xmlns:u=\"\(serviceType)\"", content: "")
        action.content = propertyXml
        body.content = action.description
        root.content = body.description
        return root.description
    }
}
