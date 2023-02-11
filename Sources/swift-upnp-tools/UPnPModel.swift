//
// UPnPModel.swift
// 

import Foundation
import SwiftXml

/**
 UPnP Model (Base class)
 */
public class UPnPModel : OrderedProperties {

    /**
     to xml
     */
    public var propertyXml: String {
        var str = ""
        for field in fields {
            str += XmlTag(name: field.key, text: field.value).description
        }
        return str
    }

    /**
     utility: read name-value formatted tag
     */
    static func readNameValue(element: XmlNode) -> (String?, String?) {
        if let elements = element.elements {
            guard elements.isEmpty else {
                return (nil, nil)
            }
        }
        guard let name = element.name, name.isEmpty == false else {
            return (nil, nil)
        }
        guard let firstText = element.firstText else {
            return (name, nil)
        }
        return (name, firstText.text)   
    }
}

/**
 UPnP Time Based Model (Base class)
 */
public class UPnPTimeBasedModel : UPnPModel {
    var _timeBase: TimeBase
    var timeBase: TimeBase {
        return _timeBase
    }

    public init(timeout: UInt64 = 1800) {
        _timeBase = TimeBase(timeout: timeout)
    }
    
    public func renewTimeout() {
        _timeBase.renewTimeout()
    }
    
    public var isExpired: Bool {
        return _timeBase.isExpired
    }
}

