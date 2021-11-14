//
// UPnPUsn.swift
//

import Foundation

// UPnP Usn
public class UPnPUsn {

    // uuid
    public var uuid: String
    // type
    public var type: String

    public init(uuid: String = "", type: String = "") {
        self.uuid = uuid
        self.type = type
    }

    public var description: String {
        if type.isEmpty {
            return uuid
        }
        return "\(uuid)::\(type)"
    }

    // read from string
    public static func read(text: String) -> UPnPUsn {
        let usn = UPnPUsn()
        let tokens = text.components(separatedBy: "::")
        usn.uuid = tokens[0]
        if tokens.count > 1 {
            usn.type = tokens[1]
        }
        return usn
    }
}
