//
// SSDPHeader.swift
// 

import Foundation

/**
 NTS (Notification Types)
 */
public enum NTS: String {
    case alive = "ssdp:alive"
    case update = "ssdp:update"
    case byebye = "ssdp:byebye"
}

/**
 SSDP Header
 */
public class SSDPHeader : OrderedCaseInsensitiveProperties {
    /**
     first line parts
     */
    public var firstLineParts: [String] = []
    /**
     firstline
     */
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

    /**
     test if it is mesarch
     */
    public var isMsearch: Bool {
        get {
            return firstLineParts[0].compare("M-SEARCH") == .orderedSame
        }
    }

    /**
     test if it is notify
     */
    public var isNotify: Bool {
        get {
            return firstLineParts[0].compare("NOTIFY") == .orderedSame
        }
    }

    /**
     test if it is http response
     */
    public var isHttpResponse: Bool {
        get {
            return firstLineParts[0].hasPrefix("HTTP/")
        }
    }

    /**
     test if it is notify alive
     */
    public var isNotifyAlive: Bool {
        get {
            guard let nts = self["NTS"] else {
                return false
            }
            return NTS(rawValue: nts) == .alive
        }
    }

    /**
     test if it is notify update
     */
    public var isNotifyUpdate: Bool {
        get {
            guard let nts = self["NTS"] else {
                return false
            }
            return NTS(rawValue: nts) == .update
        }
    }

    /**
     test if it is notify byebye
     */
    public var isNotifyByeBye: Bool {
        get {
            guard let nts = self["NTS"] else {
                return false
            }
            return NTS(rawValue: nts) == .byebye
        }
    }

    /**
     NTS (Notify Types)
     */
    public var nts: NTS? {
        get {
            guard let nts = self["NTS"] else {
                return nil
            }
            return NTS(rawValue: nts)
        }
    }

    /**
     USN
     */
    public var usn: UPnPUsn? {
        get {
            guard let usn = self["USN"] else {
                return nil
            }
            return UPnPUsn.read(text: usn)
        }
        set(newValue) {
            guard let usn = newValue else {
                self["UDN"] = nil
                return
            }
            self["USN"] = usn.description
        }
    }

    public var description: String {
        let headerFields = fields.map {"\($0.key): \($0.value)"}.joined(separator: "\r\n")
        return "\(firstLine!)\r\n\(headerFields)\r\n\r\n"
    }

    /**
     Read from string
     */
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
