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

    /**
     SEQ
     */
    public var seq: UInt32 = 0
    
    public init(udn: String, service: UPnPService, sid: String, callbackUrls: [URL] = [], timeout: UInt64 = 1800) {
        self.udn = udn
        self.service = service
        self.sid = sid
        self.callbackUrls = callbackUrls
        super.init(timeout: timeout)
    }

    /**
     Callback Urls field value
     */
    public var callbackUrlsString: String {
        return callbackUrls.map {"<\($0)>"}.joined(separator: " ")
    }

    /**
     Timeout field value
     */
    public var timeoutString: String {
        return "Second-\(timeout)"
    }

    /**
     Seq field value
     */
    public var seqString: String {
        get {
            return String(seq)
        }
    }

    /**
     Increase Sequence by 1
     */
    public func incSeq() {
        if self.seq < UInt32.max {
            self.seq += 1
        } else {
            self.seq = 1
        }
    }

    /**
     Make UPNP Event Subscription
     */
    public static func make(udn: String, service: UPnPService, callbackUrls: [URL]) -> UPnPEventSubscription {
        let sid = "uuid:\(NSUUID().uuidString.lowercased())"
        return UPnPEventSubscription(udn: udn, service: service, sid: sid, callbackUrls: callbackUrls)
    }
}
