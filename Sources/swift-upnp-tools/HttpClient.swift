//
// HttpClient.swift
// 

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/**
 Http Client Delegate
 */
public typealias HttpClientDelegate = (Data?, URLResponse?, Error?) -> Void

/**
 Simple Http Client
 */
public class HttpClient {

    /**
     url to request
     */
    var url: URL
    /**
     http method
     */
    var method: String?
    /**
     data
     */
    var data: Data?
    /**
     content type
     */
    var contentType: String?
    /**
     header fields
     */
    var fields: [KeyValuePair]?
    /**
     delegate
     */
    var delegate: HttpClientDelegate?

    public init(url: URL) {
        self.url = url
    }

    public init(url: URL, delegate: HttpClientDelegate?) {
        self.url = url
        self.delegate = delegate
    }

    public init(url: URL, method: String?, data: Data?, contentType: String?, delegate: HttpClientDelegate?) {
        self.url = url
        self.method = method
        self.data = data
        self.contentType = contentType
        self.delegate = delegate
    }

    public init(url: URL, method: String?, fields: [KeyValuePair]?, delegate: HttpClientDelegate?) {
        self.url = url
        self.method = method
        self.fields = fields
        self.delegate = delegate
    }

    public init(url: URL, method: String?, data: Data?, fields: [KeyValuePair]?, delegate: HttpClientDelegate?) {
        self.url = url
        self.method = method
        self.data = data
        self.fields = fields
        self.delegate = delegate
    }

    /**
     Start request
     */
    public func start() {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        var request = URLRequest(url: self.url)
        if let method = self.method {
            request.httpMethod = method
        }
        if let data = self.data {
            request.httpBody = data
        }
        if let contentType = self.contentType {
            request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if let fields = self.fields {
            for field in fields {
                request.addValue(field.value, forHTTPHeaderField: field.key)
            }
        }
        let task = session.dataTask(with: request) {
            (data, response, error) in

            if let delegate = self.delegate {
                delegate(data, response, error)
            }
        }
        task.resume()
    }
}
