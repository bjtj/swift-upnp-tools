//
// UPnPActionArgument.swift
// 

import Foundation
import SwiftXml

/**
 UPnP Action Argument (Model)
 */
public class UPnPActionArgument : UPnPModel {

    /**
     name
     */
    public var name: String? {
        get { return self["name"] }
        set(value) { self["name"] = value }
    }

    /**
     direction
     */
    public var direction: UPnPActionArgumentDirection? {
        get {
            guard let direction = self["direction"] else {
                return nil
            }
            return UPnPActionArgumentDirection(rawValue: direction)
        }
        set(value) {
            guard let direction = value else {
                return
            }
            self["direction"] = direction.rawValue
        }
    }

    /**
     related state variable
     */
    public var relatedStateVariable: String? {
        get { return self["relatedStateVariable"] }
        set(value) { self["relatedStateVariable"] = value }
    }

    /**
     read from xml element
     */
    public static func read(xmlElement: XmlElement) -> UPnPActionArgument {
        let argument = UPnPActionArgument()
        guard let elements = xmlElement.elements else {
            return argument
        }
        for element in elements {
            if element.firstText != nil && element.elements!.isEmpty {
                argument[element.name!] = element.firstText!.text
            }
        }
        return argument
    }

    public var description: String {
        let tag = XmlTag(name: "argument", content: propertyXml)
        return tag.description
    }
}
