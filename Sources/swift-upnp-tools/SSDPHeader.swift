import Foundation


public enum NTS: String {
    case Alive = "ssdp:alive"
    case Update = "ssdp:update"
    case Byebye = "ssdp:byebye"
}

public class SSDPHeader : OrderedCaseInsensitiveProperties {
    public var firstLineParts: [String] = []
    public var _firstLine: String = ""
    public var firstLine: String? {
        get {
            return _firstLine
        }
        set(newValue) {
            _firstLine = newValue!
            let tokens = newValue!.split(separator: " ", maxSplits: 2)
            firstLineParts.removeAll()
            firstLineParts += tokens.map { "\($0)" }
        }
    }

    public var isMsearch: Bool {
        get {
            return firstLineParts[0].compare("M-SEARCH") == .orderedSame
        }
    }

    public var isNotify: Bool {
        get {
            return firstLineParts[0].compare("NOTIFY") == .orderedSame
        }
    }

    public var isHttpResponse: Bool {
        get {
            return firstLineParts[0].hasPrefix("HTTP/")
        }
    }

    public var isNotifyAlive: Bool {
        get {
            return self["NTS"]!.compare("ssdp:alive") == .orderedSame
        }
    }

    public var isNotifyUpdate: Bool {
        get {
            return self["NTS"]!.compare("ssdp:update") == .orderedSame
        }
    }

    public var isNotifyByeBye: Bool {
        get {
            return self["NTS"]!.compare("ssdp:byebye") == .orderedSame
        }
    }

    public var nts: NTS {
        get {
            return NTS(rawValue: self["NTS"]!)!
        }
    }

    public var description: String {
        let headerFields = fields.map {"\($0.key): \($0.value)"}.joined(separator: "\r\n")
        return "\(firstLine!)\r\n\(headerFields)\r\n\r\n"
    }

    public static func read(text: String) -> SSDPHeader {
        let header = SSDPHeader()
        var first = true
        let lines = text.components(separatedBy: "\r\n")
        for line in lines {
            if line.isEmpty {
                break
            }
            if first {
                first = false
                header.firstLine = line
            } else {
                let tokens = line.split(separator: ":", maxSplits: 1)
                header[tokens[0].trimmingCharacters(in: .whitespaces)] =
                  (tokens.count == 1 ? "" : tokens[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        return header
    }
}
