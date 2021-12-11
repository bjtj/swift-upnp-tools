//
// UPnPIcon.swift
// 

import Foundation
import SwiftXml

/**
 UPnP Icon (Model)
 */
public class UPnPIcon : UPnPModel {

    /**
     mimetype
     */
    public var mimeType: String? {
        get { return self["mimetype"] }
        set(value) { self["mimetype"] = value }
    }

    /**
     width string
     */
    public var widthString: String? {
        get { return self["width"] }
        set(value) { self["width"] = value }
    }

    /**
     width
     */
    public var width: Int? {
        get { return Int(widthString ?? "") }
        set(value) {
            guard let value = value else {
                widthString = nil
                return
            }
            widthString = "\(value)"
        }
    }

    /**
     height string
     */
    public var heightString: String? {
        get { return self["height"] }
        set(value) { self["height"] = value }
    }

    /**
     height
     */
    public var height: Int? {
        get {
            return Int(heightString ?? "")
        }
        set(value) {
            guard let value = value else {
                heightString = nil
                return
            }
            heightString = "\(value)"
        }
    }

    /**
     depth string
     */
    public var depthString: String? {
        get { return self["depth"] }
        set(value) { self["depth"] = value }
    }

    /**
     depth
     */
    public var depth: Int? {
        get { return Int(depthString ?? "") }
        set(value) {
            guard let value = value else {
                depthString = nil
                return
            }
            depthString = "\(value)"
        }
    }

    /**
     url
     */
    public var url: String? {
        get { return self["url"] }
        set(value) { self["url"] = value }
    }

    /**
     read from xml string
     */
    public static func read(xmlString: String) -> UPnPIcon? {
        let doc = parseXml(xmlString: xmlString)
        guard let rootElement = doc.rootElement else {
            return nil
        }
        return read(xmlElement: rootElement)
    }

    /**
     read from xml element
     */
    public static func read(xmlElement: XmlElement) -> UPnPIcon? {
        let icon = UPnPIcon()
        guard let elements = xmlElement.elements else {
            print("UPnPIcon::read() error - no xml elements")
            return nil
        }
        for element in elements {
            let (_name, value) = readNameValue(element: element)
            guard let name = _name else {
                continue
            }
            icon[name] = value ?? ""
        }
        return icon
    }

    public var description: String {
        let tag = XmlTag(name: "icon", content: propertyXml)
        return tag.description
    }
}
