//
// UPnPSoapResponse.swift
// 

import SwiftXml

/**
 UPnP Soap Response
 */
public class UPnPSoapResponse : UPnPModel {

    /**
     service type
     */
    public var serviceType: String
    /**
     action name
     */
    public var actionName: String

    public init(serviceType: String = "", actionName: String = "") {
        self.serviceType = serviceType
        self.actionName = actionName
    }

    /**
     read from xml string
     */
    public static func read(xmlString: String) -> UPnPSoapResponse? {
        let document = parseXml(xmlString: xmlString)
        guard let root = document.rootElement else {
            return nil
        }
        guard let elements = root.elements, elements.isEmpty == false else {
            return nil
        }

        guard let name = elements[0].name, name == "Body" else {
            print("UPnPSoapResponse::read() error -- NO BODY TAG")
            return nil
        }

        guard let bodyElements = elements[0].elements, bodyElements.isEmpty == false else {
            print("UPnPSoapResponse::read() error -- empty actionElements")
            return nil
        }

        let actionElement = bodyElements[0]

        guard let actionName = actionElement.name else {
            print("UPnPSoapResponse::read() error -- no action name")
            return nil
        }

        guard actionName.hasSuffix("Response") else {
            print("UPnPSoapResponse::read() error -- action name' suffix is not Response")
            return nil
        }

        let response = UPnPSoapResponse()
        
        let end = actionName.index(actionName.endIndex, offsetBy: -"Response".count)
        response.actionName = String(actionName[actionName.startIndex..<end])
        
        guard let attributes = actionElement.attributes, attributes.isEmpty == false else {
            print("UPnPSoapRequest::read() error -- no service type")
            return nil
        }

        response.serviceType = "\(attributes[0].value ?? "")"

        if let resultElements = actionElement.elements {
            for resultElement in resultElements {
                let (_name, value) = readNameValue(element: resultElement)
                guard let name = _name else {
                    continue
                }
                response[name] = value ?? ""
            }
        }

        return response
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
        let action = XmlTag(namespace: "u", name: "\(actionName)Response", ext: "xmlns:u=\"\(serviceType)\"", content: "")
        action.content = propertyXml
        body.content = action.description
        root.content = body.description
        return root.description
    }
}
