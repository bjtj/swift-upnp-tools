//
// UPnPEventSub.swift
// 

import Foundation
import SwiftXml

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/**
 UPnP Event Subscriber
 */
public class UPnPEventSubscriber : TimeBase {

    /**
     Subscribe Completion Handler
     - Parameter subscriber
     - Parameter error
     */
    public typealias subscribeCompletionHandler = (UPnPEventSubscriber?, Error?) -> Void

    /**
     Renew subscribe completion handler
     - Parameter sid
     - Parameter error
     */
    public typealias renewSubscribeCompletionHandler = (UPnPEventSubscriber?, Error?) -> Void

    /**
     Unsubscribe completion handler
     - Parameter sid
     - Parameter error
     */
    public typealias unsubscribeCompletionHandler = (UPnPEventSubscriber?, Error?) -> Void

    /**
     Notification handler
     - Parameter subscriber
     - Parameter properties
     - Parameter error
     */
    public typealias eventNotificationHandler = (UPnPEventSubscriber?, UPnPEventProperties?, Error?) -> Void
    

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
    var notificationHandler: eventNotificationHandler?
    
    /**
     SID (Subscription ID)
     */
    public var sid: String?

    public init?(udn: String, service: UPnPService, callbackUrls: [URL], timeout: UInt64 = 1800, notificationHandler: eventNotificationHandler? = nil) {
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
    public func subscribe(completionHandler: (subscribeCompletionHandler)? = nil) {
        var fields = [KeyValuePair]()
        fields.append(KeyValuePair(key: "NT", value: "upnp:event"))
        fields.append(KeyValuePair(key: "CALLBACK", value: callbackUrls.map{"<\($0)>"}.joined(separator: " ")))
        fields.append(KeyValuePair(key: "TIMEOUT", value: "Second-\(timeout)"))
        HttpClient(url: url, method: "SUBSCRIBE", fields: fields) {
            (data, response, error) in

            guard error == nil else {
                self.error = error
                completionHandler?(self, UPnPError.custom(string: "UPnPEventSubscriber::subscribe() error - '\(error!)'"))
                return
            }
            
            guard let response = response as? HTTPURLResponse else {
                completionHandler?(self, UPnPError.custom(string: "UPnPEventSubscriber::subscribe() error - not http url response"))
                return
            }

            guard let sid = self.getValueCaseInsensitive(response: response, key: "SID") else {
                completionHandler?(self, UPnPError.custom(string: "UPnPEventSubscriber::subscribe() error - no SID found"))
                return
            }

            self.timeout = self.extractSecond(fromTimeout: self.getValueCaseInsensitive(response: response, key: "TIMEOUT"))

            self.sid = sid
            completionHandler?(self, nil)
        }.start()
    }

    func extractSecond(fromTimeout timeout: String?, minTimeoutSecond: UInt64 = 1800) -> UInt64 {
        guard let timeout = timeout else {
            return minTimeoutSecond
        }

        let start = timeout.index(timeout.startIndex, offsetBy: "Second-".count)
        return max(UInt64(String(timeout[start..<timeout.endIndex])) ?? minTimeoutSecond, minTimeoutSecond)
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
    public func renewSubscribe(completionHandler: renewSubscribeCompletionHandler? = nil) {
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
                self.error = error
                completionHandler?(self, error)
                return
            }

            guard let response = response as? HTTPURLResponse else {
                completionHandler?(self, UPnPError.custom(string: "UPnPEventSubscriber::subscribe() error - not http url response"))
                return
            }

            guard let sid = self.getValueCaseInsensitive(response: response, key: "SID") else {
                completionHandler?(self, UPnPError.custom(string: "UPnPEventSubscriber::subscribe() error - no SID found"))
                return
            }

            self.timeout = self.extractSecond(fromTimeout: self.getValueCaseInsensitive(response: response, key: "TIMEOUT"))
            self.renewTimeout()
            self.sid = sid
            completionHandler?(self, nil)
        }.start()
    }

    
    /**
     Unsubscribe
     */
    public func unsubscribe(completionHandler: unsubscribeCompletionHandler? = nil) {
        guard let sid = sid else {
            print("UPnPEventSubscriber::unsubscribe() error - no sid")
            return
        }
        var fields = [KeyValuePair]()
        fields.append(KeyValuePair(key: "SID", value: sid))
        HttpClient(url: url, method: "UNSUBSCRIBE", fields: fields) {
            (data, response, error) in
            guard error == nil else {
                completionHandler?(self, error)
                return
            }
            completionHandler?(self, nil)
        }.start()
    }

    /**
     set on notification handler
     */
    public func onNotification(notificationHandler: eventNotificationHandler?) {
        self.notificationHandler = notificationHandler
    }

    /**
     handle notification
     */
    public func handleNotification(properties: UPnPEventProperties?, error: Error?) {
        notificationHandler?(self, properties, error)
    }
}


