import Foundation
import SwiftXml

public protocol EventSubscribeDelegate {
    func onEventSubscribe(subscription: UPnPEventSubscription)
    func onRenewEventSubscription(subscription: UPnPEventSubscription)
    func onEventUnsubscribe(subscription: UPnPEventSubscription)
}

public typealias OnEventSubscription = (UPnPEventSubscription?) -> Void

public class SubscribeHandler : HttpClientDelegate {
    var handler: OnEventSubscription?
    public init(handler: OnEventSubscription?) {
        self.handler = handler
    }
    public func onError(error: Error?) {
        guard let handler = self.handler else {
            return
        }
        handler(nil)
    }
    public func onHttpResponse(data: Data?, response: URLResponse?) {
        guard let handler = self.handler else {
            return
        }
        guard let response = response as? HTTPURLResponse else {
            handler(nil)
            return
        }
        
        guard let sid = response.allHeaderFields["SID"] as? String else {
            handler(nil)
            return
        }

        var second: UInt64 = 1800
        if let timeout = response.allHeaderFields["TIMEOUT"] as? String {
            let start = timeout.index(timeout.startIndex, offsetBy: "Second-".count)
            second = UInt64(String(timeout[start..<timeout.endIndex]))!
        }
        let subscription = UPnPEventSubscription(sid: sid, timeout: second)
        handler(subscription)
    }
}

public func subscribeEvent(url: URL, callbackUrls: [URL], handler: OnEventSubscription?) {
    var fields = [KeyValuePair]()
    fields.append(KeyValuePair(key: "NT", value: "upnp:event"))
    fields.append(KeyValuePair(key: "CALLBACK", value: callbackUrls.map{"<\($0)>"}.joined(separator: " ")))
    fields.append(KeyValuePair(key: "TIEMOUT", value: "Second-1800"))
    HttpClient(url: url, method: "SUBSCRIBE", fields: fields, handler: nil).start()
}

public func unsubscribeEvent(url: URL, subscription: UPnPEventSubscription, handler: OnEventSubscription?) {
    var fields = [KeyValuePair]()
    fields.append(KeyValuePair(key: "SID", value: subscription.sid))
    HttpClient(url: url, method: "UNSUBSCRIBE", fields: fields, handler: nil).start()
}

public func renewEventSubscription(url: URL, subscription: UPnPEventSubscription, handler: OnEventSubscription?) {
    var fields = [KeyValuePair]()
    fields.append(KeyValuePair(key: "SID", value: subscription.sid))
    fields.append(KeyValuePair(key: "TIEMOUT", value: "Second-1800"))
    HttpClient(url: url, method: "SUBSCRIBE", fields: fields, handler: nil).start()
}


public class UPnPEventSubscription {
    public var timeBase: TimeBase
    public var sid: String
    public var callbackUrls = [URL]()
    public init(sid: String, timeout: UInt64 = 1800) {
        self.sid = sid
        self.timeBase = TimeBase(timeout: timeout)
    }

    public func renewTimeout() {
        timeBase.renewTimeout()
    }

    public var isExpired: Bool {
        return timeBase.isExpired
    }

    public var callbackUrlsString: String {
        return callbackUrls.map {"<\($0)>"}.joined(separator: " ")
    }

    public var timeoutString: String {
        return "Second-\(timeBase.timeout)"
    }
}

public class UPnPEventProperties: OrderedProperties {

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
