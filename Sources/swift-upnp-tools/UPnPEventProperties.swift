//
// UPnPEventProperties.swift
// 

import Foundation
import SwiftXml

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/**
 UPnP Event Properties
 */
public class UPnPEventProperties: UPnPModel {

    override public init() {
    }

    public init(fromDict dict: [String:String]) {
        super.init()
        for (key, value) in dict {
            self[key] = value
        }
    }

    /**
     read from xml string
     */
    public static func read(xmlString: String) throws -> UPnPEventProperties? {
        let document = try XmlParser.parse(xmlString: xmlString)
        guard let root = document.rootElement else {
            return nil
        }
        guard let elements = root.elements else {
            return nil
        }
        let property = UPnPEventProperties()
        for element in elements {
            if element.name == "property" {
                guard let child = element.elements, child.count == 1 else {
                    continue
                }
                
                let (_name, value) = readNameValue(element: child[0])
                guard let name = _name else {
                    continue
                }
                property[name] = value ?? ""
            }
        }
        return property
    }

    /**
     get xml document
     */
    public var xmlDocument: String {
        return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n\(self.description)"
    }
    
    public var description: String {
        let ext = "xmlns:e=\"urn:schemas-upnp-org:event-1-0\""
        let root = XmlTag(namespace: "e", name: "propertyset", ext: ext, content: "")
        for field in fields {
            let property = XmlTag(namespace: "e", name: "property", content: "")
            property.content = XmlTag(name: field.key, text: field.value).description
            root.content += property.description
        }
        return root.description
    }
}
