import Foundation
import SwiftXml


public typealias OnEventSubscription = (UPnPEventSubscription?) -> Void


public class UPnPEventSubscription : TimeBase{
    public var sid: String
    public var callbackUrls = [URL]()
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

public class UPnPEventProperties: OrderedProperties {

    override public init() {
    }

    public init(fromDict dict: [String:String]) {
        super.init()
        for (key, value) in dict {
            self[key] = value
        }
    }

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
            let value = field.value ?? ""
            property.content = XmlTag(name: field.key, text: value).description
            root.content += property.description
        }
        return root.description
    }
}


public class UPnPEventSubscriber : TimeBase {

    public var service: UPnPService
    public var url: URL
    public var callbackUrls = [URL]()
    public var sid: String?

    public init(service: UPnPService, callbackUrls: [URL], timeout: UInt64 = 1800) {
        self.service = service
        self.callbackUrls = callbackUrls
        url = service.eventSubUrlFull!
        super.init(timeout: timeout)
    }

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


public func readCallbackUrls(text: String) -> [URL] {
    let tokens = text.split(separator: " ")
    let urls = tokens.map { URL(string: unwrap(text: String($0), prefix: "<", suffix: ">"))! }
    return urls
}

public func unwrap(text: String, prefix: String, suffix: String) -> String {
    return String(text[text.index(text.startIndex, offsetBy: prefix.count)..<text.index(text.endIndex, offsetBy: -suffix.count)])
}
