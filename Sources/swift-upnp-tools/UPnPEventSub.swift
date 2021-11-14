//
// UPnPEventSub.swift
// 

import Foundation
import SwiftXml

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// On Event Subscription Type
public typealias OnEventSubscription = (UPnPEventSubscription?) -> Void

// UPnP Event Subscription Model
public class UPnPEventSubscription : TimeBase{

    // SID (Subscription ID)
    public var sid: String
    // Callback URLs
    public var callbackUrls = [URL]()
    // UPnP Service
    public var service: UPnPService?
    
    public init(service: UPnPService?, sid: String, callbackUrls: [URL] = [], timeout: UInt64 = 1800) {
        self.service = service
        self.sid = sid
        self.callbackUrls = callbackUrls
        super.init(timeout: timeout)
    }

    public var callbackUrlsString: String {
        return callbackUrls.map {"<\($0)>"}.joined(separator: " ")
    }

    public var timeoutString: String {
        return "Second-\(timeout)"
    }

    public static func generate(service: UPnPService, callbackUrls: [URL]) -> UPnPEventSubscription {
        let sid = NSUUID().uuidString.lowercased()
        return UPnPEventSubscription(service: service, sid: sid, callbackUrls: callbackUrls)
    }
}

// UPnP Event Properties
public class UPnPEventProperties: OrderedProperties {

    override public init() {
    }

    public init(fromDict dict: [String:String]) {
        super.init()
        for (key, value) in dict {
            self[key] = value
        }
    }

    // read from xml string
    public static func read(xmlString: String) -> UPnPEventProperties? {
        let document = parseXml(xmlString: xmlString)
        guard let root = document.rootElement else {
            return nil
        }
        guard let elements = root.elements else {
            return nil
        }
        let property = UPnPEventProperties()
        for element in elements {
            if element.name == "property" && element.elements != nil && element.elements!.isEmpty == false {
                let propertyElement = element.elements![0]
                property[propertyElement.name!] = propertyElement.firstText == nil ? "" : propertyElement.firstText!.text!
            }
        }
        return property
    }

    // get xml document
    public var xmlDocument: String {
        return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n\(self.description)"
    }
    
    public var description: String {
        let ext = "xmlns:e=\"urn:schemas-upnp-org:event-1-0\""
        let root = XmlTag(namespace: "e", name: "propertyset", ext: ext, content: "")
        for field in fields {
            let property = XmlTag(namespace: "e", name: "property", content: "")
            property.content = XmlTag(name: field.key, text: field.value).description
            root.content += property.description
        }
        return root.description
    }
}

// UPnP Event Subscriber
public class UPnPEventSubscriber : TimeBase {

    // UPnP Service
    public var service: UPnPService
    // Url
    public var url: URL
    // Callback Urls
    public var callbackUrls = [URL]()
    // SID (Subscription ID)
    public var sid: String?

    public init(service: UPnPService, callbackUrls: [URL], timeout: UInt64 = 1800) {
        self.service = service
        self.callbackUrls = callbackUrls
        url = service.eventSubUrlFull!
        super.init(timeout: timeout)
    }

    // Subscribe
    public func subscribe(completeListener: ((UPnPEventSubscription) -> Void)? = nil) {
        var fields = [KeyValuePair]()
        fields.append(KeyValuePair(key: "NT", value: "upnp:event"))
        fields.append(KeyValuePair(key: "CALLBACK", value: callbackUrls.map{"<\($0)>"}.joined(separator: " ")))
        fields.append(KeyValuePair(key: "TIEMOUT", value: "Second-\(timeout)"))
        HttpClient(url: url, method: "SUBSCRIBE", fields: fields) {
            (data, response, error) in

            guard error == nil else {
                print("error - \(error!)")
                return
            }
            
            guard let response = response as? HTTPURLResponse else {
                print("not http url response")
                return
            }
            
            guard let sid = response.allHeaderFields["SID"] as? String else {
                print("no sid")
                return
            }

            var second: UInt64 = 1800
            if let timeout = response.allHeaderFields["TIMEOUT"] as? String {
                let start = timeout.index(timeout.startIndex, offsetBy: "Second-".count)
                second = UInt64(String(timeout[start..<timeout.endIndex]))!
            }
            self.sid = sid
            let subscription = UPnPEventSubscription(service: self.service, sid: sid, timeout: second)
            completeListener?(subscription)
        }.start()
    }

    // Review Subscription
    public func renewSubscribe() {

        guard let sid = sid else {
            return
        }
        
        var fields = [KeyValuePair]()
        fields.append(KeyValuePair(key: "SID", value: sid))
        fields.append(KeyValuePair(key: "TIEMOUT", value: "Second-\(timeout)"))
        HttpClient(url: url, method: "SUBSCRIBE", fields: fields) {
            (data, response, error) in
        }.start()
    }

    // Unsubscribe
    public func unsubscribe() {
        guard let sid = sid else {
            return
        }
        var fields = [KeyValuePair]()
        fields.append(KeyValuePair(key: "SID", value: sid))
        HttpClient(url: url, method: "UNSUBSCRIBE", fields: fields) {
            (data, response, error) in
            
        }.start()
    }
}

// Read Callback URLs
public func readCallbackUrls(text: String) -> [URL] {
    let tokens = text.split(separator: " ")
    let urls = tokens.map { URL(string: unwrap(text: String($0), prefix: "<", suffix: ">"))! }
    return urls
}

// Unwrap
public func unwrap(text: String, prefix: String, suffix: String) -> String {
    return String(text[text.index(text.startIndex, offsetBy: prefix.count)..<text.index(text.endIndex, offsetBy: -suffix.count)])
}
