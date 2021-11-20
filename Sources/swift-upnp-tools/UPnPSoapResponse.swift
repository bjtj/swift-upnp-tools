//
// UPnPSoapResponse.swift
// 

import SwiftXml

/**
 UPnP Soap Response
 */
public class UPnPSoapResponse : OrderedProperties {

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
        guard let elements = root.elements else {
            return nil
        }
        for element in elements {
            if element.name! == "Body" {
                if let actionElements = element.elements {
                    if actionElements.isEmpty == false {
                        let response = UPnPSoapResponse()
                        let actionElement = actionElements[0]
                        if let attributes = actionElement.attributes {
                            if attributes.isEmpty == false {
                                if attributes[0].value != nil {
                                    response.serviceType = attributes[0].value!
                                }
                            }
                        }
                        response.actionName = actionElement.name!
                        let actionName = response.actionName
                        if actionName.hasSuffix("Response") {
                            let start = actionName.startIndex
                            let offset = -"Response".count
                            let end = actionName.index(actionName.endIndex, offsetBy: offset)
                            response.actionName = String(actionName[start..<end])
                        }
                        if let propElements = actionElement.elements {
                            for propElement in propElements {
                                if let firstText = propElement.firstText {
                                    response[propElement.name!] = firstText.text
                                }
                            }
                        }
                        return response
                    }
                }
            }
        }
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
        let action = XmlTag(namespace: "u", name: "\(actionName)Response", ext: "xmlns:u=\"\(serviceType)\"", content: "")
        for field in fields {
            action.content += XmlTag(name: field.key, text: field.value).description
        }
        body.content = action.description
        root.content = body.description
        return root.description
    }
}