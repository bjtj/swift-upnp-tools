//
// UPnPActionRequest.swift
// 

import Foundation

/**
 UPnP Actio Request
 */
public class UPnPActionRequest {

    /**
     action name
     */
    public var actionName: String
    /**
     fields
     */
    public var fields: OrderedProperties

    convenience init(actionName: String) {
        self.init(actionName: actionName, fields: nil)
    }

    public init(actionName: String, fields: OrderedProperties?) {
        self.actionName = actionName
        if fields == nil {
            self.fields = OrderedProperties()
        } else {
            self.fields = fields!
        }
    }
}
