//
// UPnPAction.swift
// 

import Foundation
import SwiftXml

/**
 UPnP Action (Model)
 */
public class UPnPAction : UPnPModel {

    /**
     arguments
     */
    public var arguments = [UPnPActionArgument]()

    /**
     name
     */
    public var name: String? {
        get { return self["name"] }
        set(value) { self["name"] = value }
    }

    /**
     get argument with name
     */
    public func getArgument(name: String) -> UPnPActionArgument? {
        for argument in arguments {
            guard let _name = argument.name else {
                continue
            }
            if _name == name {
                return argument
            }
        }
        return nil
    }

    /**
     read from xml element
     */
    public static func read(xmlElement: XmlElement) -> UPnPAction {
        let action = UPnPAction()
        guard let elements = xmlElement.elements else {
            return action
        }
        for element in elements {
            if element.name == "argumentList" {
                let argument = UPnPActionArgument.read(xmlElement: element)
                action.arguments.append(argument)
            } else if element.firstText != nil && element.elements!.isEmpty {
                action[element.name!] = element.firstText!.text
            }
        }
        return action
    }

    public var description: String {
        let tag = XmlTag(name: "action", content: propertyXml)
        tag.content += argumentListXml
        return tag.description
    }

    /**
     get argument list in xml format
     */
    public var argumentListXml: String {
        let tag = XmlTag(name: "argumentList", content: "")
        for argument in arguments {
            tag.content += argument.description
        }
        return tag.description
    }
}
