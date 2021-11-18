//
// UPnPModel.swift
// 

import Foundation
import SwiftXml

/**
 UPnP Model (Base class)
 */
public class UPnPModel : OrderedProperties {
    public var propertyXml: String {
        var str = ""
        for field in fields {
            str += XmlTag(name: field.key, text: field.value).description
        }
        return str
    }
}

/**
 UPnP Time Base Model (Base class)
 */
public class UPnPTimeBasedModel : UPnPModel {
    var timeBase: TimeBase

    public init(timeout: UInt64 = 1800) {
        timeBase = TimeBase(timeout: timeout)
    }
    
    public func renewTimeout() {
        timeBase.renewTimeout()
    }
    
    public var isExpired: Bool {
        return timeBase.isExpired
    }
}

