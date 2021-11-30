//
// SSDPHeader.swift
// 

import Foundation

/**
 SSDP Header
 */
public class SSDPHeader : OrderedCaseInsensitiveProperties {

    var firstLineParts: [String] = []
    
    /**
     firstline
     */
    public var firstLine: String {
        get {
            return _firstLine
        }
        set(newValue) {
            _firstLine = newValue
            let tokens = newValue.split(maxSplits: 2, whereSeparator: { $0 == " " || $0 == "\t" })
            firstLineParts.removeAll()
            firstLineParts += tokens.map { "\($0.trimmingCharacters(in: .whitespaces))" }
        }
    }
    var _firstLine: String = ""

    /**
     test if it is mesarch
     */
    public var isMsearch: Bool {
        get {
            return firstLineParts[0].caseInsensitiveCompare("M-SEARCH") == .orderedSame
        }
    }

    /**
     test if it is notify
     */
    public var isNotify: Bool {
        get {
            return firstLineParts[0].caseInsensitiveCompare("NOTIFY") == .orderedSame
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
            return UPnPNts(rawValue: nts) == .alive
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
            return UPnPNts(rawValue: nts) == .update
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
            return UPnPNts(rawValue: nts) == .byebye
        }
    }

    /**
     NTS (Notify Types)
     */
    public var nts: UPnPNts? {
        get {
            guard let nts = self["NTS"] else {
                return nil
            }
            return UPnPNts(rawValue: nts)
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
        return "\(_firstLine)\r\n\(headerFields)\r\n\r\n"
    }

    /**
     Read from string
     */
    public static func read(text: String) -> SSDPHeader? {
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
