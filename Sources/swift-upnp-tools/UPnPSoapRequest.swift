//
// UPnPSoapRequest.swift
// 

import SwiftXml

/**
 UPnP Soap Request
 */
public class UPnPSoapRequest : OrderedProperties {

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
            print("SOAP -- NO ROOT ELEMENT")
            return nil
        }
        guard let elements = root.elements else {
            print("SOAP -- NO ELEMENTS")
            return nil
        }
        for element in elements {
            guard element.name == "Body" else {
                print("NO BODY TAG")
                continue
            }
            guard let actionElements = element.elements else {
                print("NO ACTION ELEMENTS")
                continue
            }
            guard actionElements.isEmpty == false else {
                print("ELEMENTS HAS NO ELEMENTS -- \(actionElements.count)")
                continue
            }

            let request = UPnPSoapRequest()
            let actionElement = actionElements[0]
            if let attributes = actionElement.attributes {
                if attributes.isEmpty == false {
                    request.serviceType = "\(attributes[0].value ?? "")"
                }
            }
            request.actionName = actionElement.name!
            if let propElements = actionElement.elements {
                for propElement in propElements {
                    if let firstText = propElement.firstText {
                        request[propElement.name!] = firstText.text
                    }
                }
            }
            return request

        }
        print("SOAP -- READ FAILED")
        print("\(xmlString)")
        return nil
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
        for field in fields {
            action.content += XmlTag(name: field.key, text: field.value).description
        }
        body.content = action.description
        root.content = body.description
        return root.description
    }
}
