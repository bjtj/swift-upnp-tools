import Foundation
import SwiftXml

public class UPnPModel : OrderedProperties {
    public var propertyXml: String {
        var str = ""
        for field in fields {
            str += XmlTag(name: field.key, text: field.literalValue).description
        }
        return str
    }
}

public class UPnPTimeBasedModel : UPnPModel {
    var timeBase: TimeBase

    public init(timeout: UInt64 = 1800) {
        timeBase = TimeBase(timeout: timeout)
        super.init()
    }
    
    public func renewTimeout() {
        timeBase.renewTimeout()
    }
    
    public var isExpired: Bool {
        return timeBase.isExpired
    }
}


public class UPnPSpecVersion : UPnPModel {
    public var major: String? {
        get { return self["major"] }
        set(value) { self["major"] = value }
    }
    public var minor: String? {
        get { return self["minor"] }
        set(value) { self["minor"] = value }
    }
    public init(major: Int = 1, minor: Int = 0) {
        super.init()
        self["major"] = "\(major)"
        self["minor"] = "\(minor)"
    }

    public static func read(xmlElement: XmlElement) -> UPnPSpecVersion? {
        guard let elements = xmlElement.elements else {
            return nil
        }

        let version = UPnPSpecVersion()
        for element in elements {
            if element.name == "major" {
                if let firstText = element.firstText {
                    version.major = firstText.text
                }
            } else if element.name == "minor" {
                if let firstText = element.firstText {
                    version.minor = firstText.text
                }
            }
        }
        return version
    }
    
    public var description: String {
        var str = ""
        if let major = major {
            str += XmlTag(name: "major", text: major).description
        }
        if let minor = minor {
            str += XmlTag(name: "minor", text: minor).description
        }
        return XmlTag(name: "specVersion", content: str).description
    }
}
