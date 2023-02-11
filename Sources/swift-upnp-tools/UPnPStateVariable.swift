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
     send events
     */
    public var sendEvents: Bool? = nil

    /**
     multicast
     */
    public var multicast: Bool? = nil

    /**
     default value
     */
    public var defaultValue: String? {
        get { return self["defaultValue"] }
        set(value) { self["defaultValue"] = value }
    }

    /**
     allowed value rannge
     */
    public var allowedValueRange: AllowedValueRange? = nil

    /**
     allowed value list
     */
    public var allowedValueList: AllowedValueList? = nil

    /**
     read from xml element
     */
    public static func read(xmlElement: XmlElement) -> UPnPStateVariable {
        let stateVariable = UPnPStateVariable()

        if let sendEvents = xmlElement.getAttribute(name: "sendEvents")?.value {
            stateVariable.sendEvents = sendEvents == "yes"
        }

        if let multicast = xmlElement.getAttribute(name: "multicast")?.value {
            stateVariable.multicast = multicast == "yes"
        }
        
        guard let elements = xmlElement.elements else {
            return stateVariable
        }
        
        for element in elements {
            if element.name == "allowedValueRange" {
                stateVariable.allowedValueRange = AllowedValueRange.read(xmlElement: element)
            } else if element.name == "allowedValueList" {
                stateVariable.allowedValueList = AllowedValueList.read(xmlElement: element)
            } else {
                let (_name, value) = readNameValue(element: element)
                guard let name = _name else {
                    continue
                }
                stateVariable[name] = value ?? ""
            }
        }
        return stateVariable
    }

    /**
     to xml
     */
    public var description: String {

        var attrs: [String] = []

        if let sendEvents = self.sendEvents {
            attrs.append("sendEvents=\"\(sendEvents ? "yes" : "no")\"")
        }

        if let multicast = self.multicast {
            attrs.append("multicast=\"\(multicast ? "yes" : "no")\"")
        }
        
        let tag = XmlTag(name: "stateVariable", ext: attrs.joined(separator: " "), content: self.propertyXml + (self.allowedValueRange?.description ?? "") + (self.allowedValueList?.description ?? ""))
        return tag.description
    }

    /**
     Allowed Value Range
     */
    public class AllowedValueRange : UPnPModel {

        public var minimum: String? {
            get { return self["minimum"] }
            set(value) { self["minimum"] = value }
        }

        public var maximum: String? {
            get { return self["maximum"] }
            set(value) { self["maximum"] = value }
        }

        public var step: String? {
            get { return self["step"] }
            set(value) { self["step"] = value }
        }

        public static func read(xmlElement: XmlElement) -> AllowedValueRange {
            let allowedValueRange = AllowedValueRange()
            guard let elements = xmlElement.elements else {
                return allowedValueRange
            }
            
            for element in elements {
                let (_name, value) = readNameValue(element: element)
                guard let name = _name else {
                    continue
                }
                allowedValueRange[name] = value ?? ""
            }
            return allowedValueRange
        }
        
        public var description: String {
            let tag = XmlTag(name: "allowedValueRange", content: self.propertyXml)
            return tag.description
        }
    }


    /**
     Allowed Value List
     */
    public class AllowedValueList {

        public var items: [String] = []

        public func append(_ value: String) {
            self.items.append(value)
        }

        public func remove(_ value: String) {
            self.items.removeAll {
                $0 == value
            }
        }

        public static func read(xmlElement: XmlElement) -> AllowedValueList? {
            let allowedValueList = AllowedValueList()
            guard let elements = xmlElement.elements else {
                return nil
            }
            
            for element in elements {
                let (_name, _value) = readNameValue(element: element)
                guard let name = _name, let value = _value, name == "allowedValue", value.isEmpty == false else {
                    continue
                }
                allowedValueList.append(value)
            }
            return allowedValueList
        }
        
        public var description: String {
            let tag = XmlTag(name: "allowedValueList", content: self.items.map({"<allowedValue>\($0)</allowedValue>"}).joined(separator: ""))
            return tag.description
        }
    }
}
