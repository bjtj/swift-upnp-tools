//
// XmlTag.swift
// 

import SwiftXml

/**
 Xml Tag Helper
 */
public class XmlTag {

    /**
     namespace
     */
    public var namespace: String?
    /**
     name
     */
    public var name: String?
    /**
     ext
     */
    public var ext: String?
    /**
     content
     */
    public var content: String

    public init(namespace: String? = nil, name: String? = nil, ext: String? = nil, content: String = "") {
        self.namespace = namespace
        self.name = name
        self.ext = ext
        self.content = content
    }

    public init(namespace: String? = nil, name: String? = nil, ext: String? = nil, text: String = "") {
        self.namespace = namespace
        self.name = name
        self.ext = ext
        self.content = XmlParser.escapeXml(text: text)
    }

    var tag: String {
        guard let name = name else {
            return ""
        }
        if let namespace = namespace, namespace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "\(namespace):\(name)"
        }
        return name
    }

    public var description: String {
        var str = "<"
        str += tag
        if let ext = ext {
            str += " \(ext)"
        }
        if content.isEmpty == false {
            str += ">\(content)</\(tag)>"
        } else {
            str += " />"
        }
        return str
    }
}
