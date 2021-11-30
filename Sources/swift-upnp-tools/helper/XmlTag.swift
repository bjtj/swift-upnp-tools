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
        self.content = escapeXml(text: text)
    }

    public var description: String {
        var str = "<"
        let tag = (namespace == nil ? "\(name!)" : "\(namespace!):\(name!)")
        str += tag
        if ext != nil {
            str += " \(ext!)"
        }
        if content.isEmpty == false {
            str += ">\(content)</\(tag)>"
        } else {
            str += " />"
        }
        return str
    }
}
