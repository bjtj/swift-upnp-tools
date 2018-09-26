import swift_xml

public class UPnPEventSubscription {
    public var timeBase: TimeBase
    public var sid: String
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
