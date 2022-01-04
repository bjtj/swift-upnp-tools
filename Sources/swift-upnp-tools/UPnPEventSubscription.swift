//
// UPnPEventSubscription.swift
// 

import Foundation
import SwiftXml


/**
 UPnP Event Subscription Model
 */
public class UPnPEventSubscription : TimeBase {

    /**
     SID (Subscription ID)
     */
    public var sid: String

    /**
     Callback URLs
     */
    public var callbackUrls = [URL]()

    /**
     UDN
     */
    public var udn: String
    
    /**
     UPnP Service
     */
    public var service: UPnPService?
    
    public init(udn: String, service: UPnPService, sid: String, callbackUrls: [URL] = [], timeout: UInt64 = 1800) {
        self.udn = udn
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

    public static func make(udn: String, service: UPnPService, callbackUrls: [URL]) -> UPnPEventSubscription {
        let sid = "sid-\(NSUUID().uuidString.lowercased())"
        return UPnPEventSubscription(udn: udn, service: service, sid: sid, callbackUrls: callbackUrls)
    }
}
