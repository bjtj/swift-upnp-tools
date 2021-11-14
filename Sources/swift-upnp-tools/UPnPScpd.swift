//
// UPnPScpd.swift
// 

import Foundation
import SwiftXml

/**
 UPnP Scpd (Model)
 */
public class UPnPScpd : UPnPModel {

    /**
     sepc version
     */
    public var specVersion: UPnPSpecVersion?
    /**
     UPnP Actions
     */
    public var actions = [UPnPAction]()
    /**
     StateVariables
     */
    public var stateVariables = [UPnPStateVariable]()

    /**
     get action with name
     */
    public func getAction(name: String) -> UPnPAction? {
        for action in actions {
            guard let _name = action.name else {
                continue
            }
            if _name == name {
                return action
            }
        }
        return nil
    }

    /**
     get state variable with name
     */
    public func getStateVariable(name: String) -> UPnPStateVariable? {
        for stateVariable in stateVariables {
            guard let _name = stateVariable.name else {
                continue
            }
            if _name == name {
                return stateVariable
            }
        }
        return nil
    }

    /**
     read from xml string
     */
    public static func read(xmlString: String) -> UPnPScpd? {
        let document = parseXml(xmlString: xmlString)
        guard let root = document.rootElement else {
            return nil
        }

        let scpd = UPnPScpd()

        guard let elements = root.elements else {
            return scpd
        }
        for element in elements {
            if element.name == "specVersion" {
                scpd.specVersion = UPnPSpecVersion.read(xmlElement: element)
            } else if element.name == "actionList" {
                scpd.actions = readActionList(xmlElement: element)
            } else if element.name == "serviceStateTable" {
                scpd.stateVariables = readStateVariables(xmlElement: element)
            }
        }
        return scpd
    }

    /**
     read action list from xml element
     */
    public static func readActionList(xmlElement: XmlElement) -> [UPnPAction] {
        var actions = [UPnPAction]()
        guard let elements = xmlElement.elements else {
            return actions
        }

        for element in elements {
            if element.name == "action" {
                let action = UPnPAction.read(xmlElement: element)
                actions.append(action)
            }
        }
        return actions
    }
    
    /**
     read state variables from xml element
     */
    public static func readStateVariables(xmlElement: XmlElement) -> [UPnPStateVariable] {
        var stateVariables = [UPnPStateVariable]()
        guard let elements = xmlElement.elements else {
            return stateVariables
        }

        for element in elements {
            if element.name == "stateVariable" {
                let stateVariable = UPnPStateVariable.read(xmlElement: element)
                stateVariables.append(stateVariable)
            }
        }
        return stateVariables
    }

    /**
     get xml document
     */
    public var xmlDocument: String {
        return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n\(self.description)"
    }

    public var description: String {
        let tag = XmlTag(name: "scpd", content: "")
        if let specVersion = specVersion {
            tag.content += specVersion.description
        }
        tag.content += actionListXml
        tag.content += serviceStateTableXml
        return tag.description
    }

    /**
     get action list in xml format
     */
    public var actionListXml: String {
        let tag = XmlTag(name: "actionList", content: "")
        for action in actions {
            tag.content += action.description
        }
        return tag.description
    }

    /**
     get service state table in xml format
     */
    public var serviceStateTableXml: String {
        let tag = XmlTag(name: "serviceStateTable", content: "")
        for stateVariable in stateVariables {
            tag.content += stateVariable.description
        }
        return tag.description
    }
}

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
            if element.firstText != nil && element.elements!.isEmpty {
                stateVariable[element.name!] = element.firstText!.text
            }
        }
        return stateVariable
    }

    public var description: String {
        let tag = XmlTag(name: "stateVariable", content: propertyXml)
        return tag.description
    }
}
