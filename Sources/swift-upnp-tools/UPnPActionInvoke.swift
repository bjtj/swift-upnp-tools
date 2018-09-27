import Foundation

public protocol SoapResponseDelegate {
    func onError(error: Error?)
    func onSoapResponse(soapResponse: UPnPSoapResponse)
}

public class UPnPActionInvoke : HttpClientDelegate {
    public var url: URL
    public var soapRequest: UPnPSoapRequest
    public var handler: SoapResponseDelegate?
    public init(url: URL, soapRequest: UPnPSoapRequest, handler: SoapResponseDelegate?) {
        self.url = url
        self.soapRequest = soapRequest
        self.handler = handler
    }

    public func onError(error: Error?) {
        guard let handler = self.handler else {
            return
        }
        handler.onError(error: error)
    }

    public func onHttpResponse(data: Data?, response: URLResponse?) {
        guard let handler = self.handler else {
            return
        }
        guard let data = data else {
            // no data
            handler.onError(error: nil)
            return
        }
        guard let text = String(data: data, encoding: .utf8) else {
            // not string
            handler.onError(error: nil)
            return
        }
        guard let soapResponse = UPnPSoapResponse.read(xmlString: text) else {
            // soap response
            handler.onError(error: nil)
            return
        }
        handler.onSoapResponse(soapResponse: soapResponse)
    }
    
    public func invoke() {
        let data = soapRequest.description.data(using: .utf8)
        HttpClient(url: url, method: "POST", data: data, contentType: "text/xml", handler: self).start()
    }
}
