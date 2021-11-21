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

    public static func read(xmlString: String) -> UPnPAction? {
        let document = parseXml(xmlString: xmlString)
        guard let root = document.rootElement else {
            print("UPnPAction::read() error - no root xml element")
            return nil
        }
        return read(xmlElement: root)
    }

    /**
     read from xml element
     */
    public static func read(xmlElement: XmlElement) -> UPnPAction? {
        let action = UPnPAction()
        guard let elements = xmlElement.elements else {
            print("UPnPAction::read() error - no xml element")
            return nil
        }
        for element in elements {
            guard let name = element.name else {
                print("UPnPAction::read() error - no element name found")
                continue
            }
            
            if name == "argumentList" {
                guard let argListElements = element.elements else {
                    print("UPnPAction::read() error - wrong arg list")
                    continue
                }
                for argElement in argListElements {
                    guard let argument = UPnPActionArgument.read(xmlElement: argElement) else {
                        print("UPnPAction::read() error - parse argument failed")
                        continue
                    }
                    action.arguments.append(argument)
                }
            } else {
                guard element.elements!.isEmpty else {
                    continue
                }
                guard let name = element.name else {
                    continue
                }
                guard let value = element.firstText!.text else {
                    continue
                }
                action[name] = value
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
