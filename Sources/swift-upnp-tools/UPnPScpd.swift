import Foundation
import SwiftXml


public class UPnPScpd : UPnPModel {
    public var specVersion: UPnPSpecVersion?
    public var actions = [UPnPAction]()
    public var stateVariables = [UPnPStateVariable]()

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

    public static func read(xmlString: String) -> UPnPScpd? {
        print("read")
        let document = parseXml(xmlString: xmlString)
        guard let root = document.rootElement else {
            print("no root element")
            print(xmlString)
            return nil
        }

        let scpd = UPnPScpd()

        guard let elements = root.elements else {
            print("no elements")
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
        print("read scpd -- done")
        return scpd
    }

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

    public var actionListXml: String {
        let tag = XmlTag(name: "actionList", content: "")
        for action in actions {
            tag.content += action.description
        }
        return tag.description
    }

    public var serviceStateTableXml: String {
        let tag = XmlTag(name: "serviceStateTable", content: "")
        for stateVariable in stateVariables {
            tag.content += stateVariable.description
        }
        return tag.description
    }
}


public class UPnPAction : UPnPModel {

    public var arguments = [UPnPActionArgument]()
    
    public var name: String? {
        get { return self["name"] }
        set(value) { self["name"] = value }
    }

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

    public var argumentListXml: String {
        let tag = XmlTag(name: "argumentList", content: "")
        for argument in arguments {
            tag.content += argument.description
        }
        return tag.description
    }
}

public class UPnPActionArgument : UPnPModel {
    public var name: String? {
        get { return self["name"] }
        set(value) { self["name"] = value }
    }

    public var relatedStateVariable: String? {
        get { return self["relatedStateVariable"] }
        set(value) { self["relatedStateVariable"] = value }
    }

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

public class UPnPStateVariable : UPnPModel {
    public var name: String? {
        get { return self["name"] }
        set(value) { self["name"] = value }
    }

    public var dataType: String? {
        get { return self["dataType"] }
        set(value) { self["dataType"] = value }
    }

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
