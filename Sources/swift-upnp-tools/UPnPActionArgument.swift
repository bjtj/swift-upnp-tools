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
    public static func read(xmlElement: XmlElement) -> UPnPActionArgument? {
        let argument = UPnPActionArgument()
        guard let elements = xmlElement.elements else {
            print("UPnPActionArgument::read() error - no xml elements")
            return nil
        }
        for element in elements {
            guard let firstText = element.firstText else {
                // ignore -- no first text
                continue
            }
            guard element.elements!.isEmpty else {
                // ignore -- has elements
                continue
            }
            guard let name = element.name else {
                print("UPnPActionArgument::read() warning - no name in element")
                continue
            }
            guard let value = firstText.text else {
                print("UPnPActionArgument::read() warning - no text in element")
                continue
            }
            argument[name] = value
        }
        return argument
    }

    public var description: String {
        let tag = XmlTag(name: "argument", content: propertyXml)
        return tag.description
    }
}
