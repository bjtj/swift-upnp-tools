
public class XmlTag {

    public var namespace: String?
    public var name: String?
    public var ext: String?
    public var content: String

    public init(namespace: String? = nil, name: String? = nil, ext: String? = nil, content: String = "") {
        self.namespace = namespace
        self.name = name
        self.ext = ext
        self.content = content
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
