

public class UPnPUsn {

    public var uuid: String?
    public var type: String?

    public var description: String {
        if type == nil {
            return uuid!
        }
        return "\(uuid!)::\(type!)"
    }

    static func read(text: String) -> UPnPUsn {
        let usn = UPnPUsn()
        let tokens = text.components(separatedBy: "::")
        usn.uuid = tokens[0]
        if tokens.count > 1 {
            usn.type = tokens[1]
        }
        return usn
    }
}
