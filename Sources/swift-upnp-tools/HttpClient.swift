import Foundation

public protocol HttpClientDelegate {
    func onHttpResponse(request: URLRequest, data: Data?, response: URLResponse?)
    func onError(error: Error?)
}

public class HttpClient {
    var url: URL
    var method: String?
    var data: Data?
    var contentType: String?
    var fields: [KeyValuePair]?
    var handler: HttpClientDelegate?

    public init(url: URL) {
        self.url = url
    }

    public init(url: URL, handler: HttpClientDelegate?) {
        self.url = url
        self.handler = handler
    }

    public init(url: URL, method: String?, data: Data?, contentType: String?, handler: HttpClientDelegate?) {
        self.url = url
        self.method = method
        self.data = data
        self.contentType = contentType
        self.handler = handler
    }

    public init(url: URL, method: String?, fields: [KeyValuePair]?, handler: HttpClientDelegate?) {
        self.url = url
        self.method = method
        self.fields = fields
        self.handler = handler
    }

    public func start() {
        // let configuration = URLSessionConfiguration.background(withIdentifier: "http-client")
        // let configuration = URLSessionConfiguration.ephemeral
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

            guard let handler = self.handler else {
                print("http client -- no handler")
                return
            }

            guard error == nil else {
                print("http client -- error \(error!)")
                handler.onError(error: error!)
                return
            }
            
            if let handler = self.handler {
                handler.onHttpResponse(request: request, data: data, response: response)
            }
        }
        task.resume()
    }
}
