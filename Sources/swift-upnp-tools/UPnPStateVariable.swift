//
// UPnPStateVariable.swift
// 

import Foundation
import SwiftXml

/**
 UPnP State Variable (Model)
 */
public class UPnPStateVariable : UPnPModel {
    /**
     name
     */
    public var name: String? {
        get { return self["name"] }
        set(value) { self["name"] = value }
    }

    /**
     data type
     */
    public var dataType: String? {
        get { return self["dataType"] }
        set(value) { self["dataType"] = value }
    }

    /**
     read from xml element
     */
    public static func read(xmlElement: XmlElement) -> UPnPStateVariable {
        let stateVariable = UPnPStateVariable()
        guard let elements = xmlElement.elements else {
            return stateVariable
        }
        for element in elements {

            let (_name, value) = readNameValue(element: element)
            guard let name = _name else {
                continue
            }
            stateVariable[name] = value ?? ""
        }
        return stateVariable
    }

    public var description: String {
        let tag = XmlTag(name: "stateVariable", content: propertyXml)
        return tag.description
    }
}
