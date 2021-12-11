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
     read from xml string
     */
    public static func read(xmlString: String) -> UPnPActionArgument? {
        let doc = parseXml(xmlString: xmlString)
        guard let rootElement = doc.rootElement else {
            return nil
        }
        return read(xmlElement: rootElement)
    }

    /**
     read from xml element
     */
    public static func read(xmlElement: XmlElement) -> UPnPActionArgument? {
        let argument = UPnPActionArgument()
        guard let elements = xmlElement.elements else {
            print("UPnPActionArgument::read() error - no xml elements")
            return nil
        }
        for element in elements {
            let (_name, value) = readNameValue(element: element)
            guard let name = _name else {
                continue
            }
            argument[name] = value ?? ""
        }
        return argument
    }

    public var description: String {
        let tag = XmlTag(name: "argument", content: propertyXml)
        return tag.description
    }
}
