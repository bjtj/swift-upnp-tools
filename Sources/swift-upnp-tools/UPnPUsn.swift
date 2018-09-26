

public class UPnPUsn {

    public var uuid = ""
    public var type = ""

    public var description: String {
        if type.isEmpty {
            return uuid
        }
        return "\(uuid)::\(type)"
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
