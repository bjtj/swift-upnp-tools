import Foundation


public class UPnPActionInvoke : HttpClientDelegate {
    public var url: URL
    public var soapRequest: UPnPSoapRequest
    public var completeHandler: ((UPnPSoapResponse?) -> Void)?
    public init(url: URL, soapRequest: UPnPSoapRequest, completeHandler: ((UPnPSoapResponse?) -> Void)?) {
        self.url = url
        self.soapRequest = soapRequest
        self.completeHandler = completeHandler
    }

    public func onError(error: Error?) {
        guard let completeHandler = self.completeHandler else {
            return
        }
        completeHandler(nil)
    }

    public func onHttpResponse(request: URLRequest, data: Data?, response: URLResponse?) {
        guard let completeHandler = self.completeHandler else {
            return
        }
        guard let data = data else {
            print("no data")
            completeHandler(nil)
            return
        }
        guard let text = String(data: data, encoding: .utf8) else {
            print("not string")
            completeHandler(nil)
            return
        }
        guard let soapResponse = UPnPSoapResponse.read(xmlString: text) else {
            print("not soap response -- \(text)")
            completeHandler(nil)
            return
        }
        completeHandler(soapResponse)
    }
    
    public func invoke() {
        let data = soapRequest.xmlDocument.data(using: .utf8)
        HttpClient(url: url, method: "POST", data: data, contentType: "text/xml", handler: self).start()
    }
}
