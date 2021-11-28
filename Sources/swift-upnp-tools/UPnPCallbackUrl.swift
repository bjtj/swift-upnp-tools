//
// UPnPCallbackUrl.swift
//

import Foundation

/**
 UPnP Callback Url
 */
class UPnPCallbackUrl {

    /**
     Read Callback URLs from text
     */
    public class func read(text: String) -> [URL] {
        let tokens = text.split(separator: " ")
        let urls = tokens.map { URL(string: unwrap(text: String($0), prefix: "<", suffix: ">"))! }
        return urls
    }

    /**
     Unwrap
     */
    class func unwrap(text: String, prefix: String, suffix: String) -> String {
        return String(text[text.index(text.startIndex, offsetBy: prefix.count)..<text.index(text.endIndex, offsetBy: -suffix.count)])
    }

    /**
     Make a Callback Url
     */
    public class func make(hostname: String, port: Int32, udn: String, serviceId: String) -> URL? {
        return URL(string: "http://\(hostname):\(port)/notify/\(udn)/\(serviceId)")
    }
}
