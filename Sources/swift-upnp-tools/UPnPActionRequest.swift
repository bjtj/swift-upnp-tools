//
// UPnPActionRequest.swift

import Foundation

// UPnP Actio Request
public class UPnPActionRequest {

    // actio name
    public var actionName: String
    // fields
    public var fields: OrderedProperties

    public init(actionName: String, fields: OrderedProperties) {
        self.actionName = actionName
        self.fields = fields
    }
}
