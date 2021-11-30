//
// HttpClient.swift
// 

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/**
 Simple Http Client
 */
public class HttpClient {

    /**
     Http Client Handler
     */
    public typealias httpClientHandler = (Data?, URLResponse?, Error?) -> Void

    var url: URL
    var method: String?
    var data: Data?
    var contentType: String?
    var fields: [KeyValuePair]?
    var delegate: httpClientHandler?

    public init(url: URL) {
        self.url = url
    }

    public init(url: URL, delegate: httpClientHandler?) {
        self.url = url
        self.delegate = delegate
    }

    public init(url: URL, method: String?, data: Data?, contentType: String?, delegate: httpClientHandler?) {
        self.url = url
        self.method = method
        self.data = data
        self.contentType = contentType
        self.delegate = delegate
    }

    public init(url: URL, method: String?, fields: [KeyValuePair]?, delegate: httpClientHandler?) {
        self.url = url
        self.method = method
        self.fields = fields
        self.delegate = delegate
    }

    public init(url: URL, method: String?, data: Data?, contentType: String?, fields: [KeyValuePair]?, delegate: httpClientHandler?) {
        self.url = url
        self.method = method
        self.data = data
        self.contentType = contentType
        self.fields = fields
        self.delegate = delegate
    }

    /**
     Start Request
     */
    public func start() {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        var request = URLRequest(url: url)
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
            self.delegate?(data, response, error)
        }
        task.resume()
    }
}
