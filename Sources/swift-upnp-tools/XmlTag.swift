
public class XmlTag {

    public var namespace: String?
    public var name: String?
    public var content: String?

    public init(namespace: String? = nil, name: String? = nil, content: String? = nil) {
        self.namespace = namespace
        self.name = name
        self.content = content
    }

    public var description: String {
        var str = "<"
        let tag = (namespace == nil ? "\(name!)" : "\(namespace!):\(name!)")
        str += tag
        if content != nil {
            str += ">\(content!)</\(tag)>"
        } else {
            str += " />"
        }
        return str
    }
}
