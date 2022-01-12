//
// HttpClient.swift
// 

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum HttpStatusRange {
    case unknown
    case information
    case success
    case redirection
    case clientError
    case serverError
}

enum HttpError: Error {
    case notSuccess(code: Int)
}

func getStatusCodeRange(response: URLResponse?) -> HttpStatusRange {
    guard let code = getStatusCode(response: response) else {
        return .unknown
    }
    return getStatusCodeRange(code: code)
}

func getStatusCodeRange(code: Int) -> HttpStatusRange {
    switch code {
    case 100..<200:
        return .information
    case 200..<300:
        return .success
    case 300..<400:
        return .clientError
    case 400..<500:
        return .serverError
    default:
        return .unknown
    }
}

func getStatusCode(response: URLResponse?, defaultValue: Int) -> Int {
    guard let code = getStatusCode(response: response) else {
        return defaultValue
    }
    return code
}

func getStatusCode(response: URLResponse?) -> Int? {

    guard response != nil else {
        return nil
    }
    
    guard let httpurlresponse = response as? HTTPURLResponse else {
        return nil
    }

    return httpurlresponse.statusCode
}

func getValueCaseInsensitive(response: URLResponse?, key: String) -> String? {

    guard let resp = response else {
        return nil
    }

    guard let httpurlresponse = resp as? HTTPURLResponse else {
        return nil
    }
    
    // TODO: fix it elengant
    // #if compiler(>=5.3)
    // return response.value(forHTTPHeaderField: key)
    // #else
    return httpurlresponse.allHeaderFields.first(where: { ($0.key as! String).description.caseInsensitiveCompare(key) == .orderedSame })?.value as? String
    // #endif
}

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
    /**
     user agent
     */
    public static var USER_AGENT: String = "OS/\(OSVER) UPnP/1.1 SwiftUpnpTool/1.0"
    
    static var OSVER: String {
        let ver = ProcessInfo.processInfo.operatingSystemVersion
        return "\(ver.majorVersion).\(ver.minorVersion).\(ver.patchVersion)"
    }
    
    /**
     user agent
     */
    public var userAgent: String? = nil

    /**
     Set request header field `Connection` to `close`
     */
    public var closeConn: Bool = true

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
        if let ua = userAgent {
            request.addValue(ua, forHTTPHeaderField: "User-Agent")
        } else {
            request.addValue(HttpClient.USER_AGENT, forHTTPHeaderField: "User-Agent")
        }
        if closeConn {
            request.addValue("close", forHTTPHeaderField: "Connection")
        }
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
