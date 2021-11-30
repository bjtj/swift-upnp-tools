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
     Sepc Version
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
     Get action with name
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
     Get state variable with name
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
     Read scpd from xml string
     */
    public static func read(xmlString: String) -> UPnPScpd? {
        let document = parseXml(xmlString: xmlString)
        guard let root = document.rootElement else {
            print("UPnPScpd::read() - error no root xml element")
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
     Read action list from xml element
     */
    public static func readActionList(xmlElement: XmlElement) -> [UPnPAction] {
        var actions = [UPnPAction]()
        guard let elements = xmlElement.elements else {
            return actions
        }

        for element in elements {
            if element.name == "action" {
                guard let action = UPnPAction.read(xmlElement: element) else {
                    print("UPnPScpd::readActionList() error - action read failed")
                    continue
                }
                actions.append(action)
            }
        }
        return actions
    }
    
    /**
     Read state variables from xml element
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
     Get scpd xml document
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
     Get action list in xml format
     */
    public var actionListXml: String {
        let tag = XmlTag(name: "actionList", content: "")
        for action in actions {
            tag.content += action.description
        }
        return tag.description
    }

    /**
     Get service state table in xml format
     */
    public var serviceStateTableXml: String {
        let tag = XmlTag(name: "serviceStateTable", content: "")
        for stateVariable in stateVariables {
            tag.content += stateVariable.description
        }
        return tag.description
    }
}

