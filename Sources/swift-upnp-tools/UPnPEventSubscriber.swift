//
// UPnPEventSub.swift
// 

import Foundation
import SwiftXml

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/**
 event subscribe handler
 */
public typealias eventSubscribeCompleteHandler = (UPnPEventSubscriber?, Error?) -> Void

/**
 event subscribe renew handler
 */
public typealias eventRenewSubscribeCompleteHandler = (String, Error?) -> Void

/**
 event unsubscribe handler
 */
public typealias eventUnsubscribeCompleteHandler = (String, Error?) -> Void


/**
 event property handler
 */
public typealias notificationHandler = (UPnPEventSubscriber?, UPnPEventProperties?, Error?) -> Void


/**
 UPnP Event Subscriber
 */
public class UPnPEventSubscriber : TimeBase {

    /**
     error
     */
    public var error: Error?

    /**
     UDN
     */
    public var udn: String

    /**
     UPnP Service
     */
    public var service: UPnPService
    
    /**
     Url
     */
    public var url: URL
    
    /**
     Callback Urls
     */
    public var callbackUrls = [URL]()

    /**
     notification handler
     */
    var notificationHandler: notificationHandler?
    
    /**
     SID (Subscription ID)
     */
    public var sid: String?

    public init?(udn: String, service: UPnPService, callbackUrls: [URL], timeout: UInt64 = 1800, notificationHandler: notificationHandler? = nil) {
        self.udn = udn
        self.service = service
        self.callbackUrls = callbackUrls
        guard let eventSubUrlFull = service.eventSubUrlFull else {
            return nil
        }
        url = eventSubUrlFull
        self.notificationHandler = notificationHandler
        super.init(timeout: timeout)
    }

    /**
     Subscribe
     */
    public func subscribe(completionHandler: (eventSubscribeCompleteHandler)? = nil) {
        var fields = [KeyValuePair]()
        fields.append(KeyValuePair(key: "NT", value: "upnp:event"))
        fields.append(KeyValuePair(key: "CALLBACK", value: callbackUrls.map{"<\($0)>"}.joined(separator: " ")))
        fields.append(KeyValuePair(key: "TIMEOUT", value: "Second-\(timeout)"))
        HttpClient(url: url, method: "SUBSCRIBE", fields: fields) {
            (data, response, error) in

            guard error == nil else {
                completionHandler?(nil, UPnPError.custom(string: "UPnPEventSubscriber::subscribe() error - '\(error!)'"))
                return
            }
            
            guard let response = response as? HTTPURLResponse else {
                completionHandler?(nil, UPnPError.custom(string: "UPnPEventSeventNotificationHandlerubscriber::subscribe() error - not http url response"))
                return
            }

            guard let sid = self.getValueCaseInsensitive(response: response, key: "SID") else {
                completionHandler?(nil, UPnPError.custom(string: "UPnPEventSubscriber::subscribe() error - no SID found"))
                return
            }

            self.sid = sid
            completionHandler?(self, nil)
        }.start()
    }

    func extractSecond(fromTimeout timeout: String?, defaultSecond: UInt64 = 1800) -> UInt64 {
        guard let timeout = timeout else {
            return defaultSecond
        }

        let start = timeout.index(timeout.startIndex, offsetBy: "Second-".count)
        return UInt64(String(timeout[start..<timeout.endIndex]))!
    }

    
    func getValueCaseInsensitive(response: HTTPURLResponse, key: String) -> String? {
        // TODO: fix it as elengant
        // #if compiler(>=5.3)
        // return response.value(forHTTPHeaderField: key)
        // #else
        return response.allHeaderFields.first(where: { ($0.key as! String).description.caseInsensitiveCompare(key) == .orderedSame })?.value as? String
        // #endif
    }
    

    /**
     Review Subscription
     */
    public func renewSubscribe(completionHandler: eventRenewSubscribeCompleteHandler? = nil) {
        guard let sid = sid else {
            print("UPnPEventSubscriber::renewSubscribe() error - no sid")
            return
        }
        
        var fields = [KeyValuePair]()
        fields.append(KeyValuePair(key: "SID", value: sid))
        fields.append(KeyValuePair(key: "TIMEOUT", value: "Second-\(timeout)"))
        HttpClient(url: url, method: "SUBSCRIBE", fields: fields) {
            (data, response, error) in
            guard error == nil else {
                completionHandler?(sid, error)
                return
            }
            completionHandler?(sid, nil)
        }.start()
    }

    
    /**
     Unsubscribe
     */
    public func unsubscribe(completionHandler: eventUnsubscribeCompleteHandler? = nil) {
        guard let sid = sid else {
            print("UPnPEventSubscriber::unsubscribe() error - no sid")
            return
        }
        var fields = [KeyValuePair]()
        fields.append(KeyValuePair(key: "SID", value: sid))
        HttpClient(url: url, method: "UNSUBSCRIBE", fields: fields) {
            (data, response, error) in
            guard error == nil else {
                completionHandler?(sid, error)
                return
            }
            completionHandler?(sid, nil)
        }.start()
    }

    /**
     set on notification handler
     */
    public func onNotification(notificationHandler: notificationHandler?) {
        self.notificationHandler = notificationHandler
    }

    /**
     handle notification
     */
    public func handleNotification(properties: UPnPEventProperties?, error: Error?) {
        notificationHandler?(self, properties, error)
    }
}


