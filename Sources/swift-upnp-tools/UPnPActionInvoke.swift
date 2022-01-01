//
// UPnPActionInvoke.swift
// 

import Foundation

/**
 UPnP Action Invoke
 */
public class UPnPActionInvoke {

    /**
     action invoke completion handler
     - Parameter upnp soap response
     - Parameter error
     */
    public typealias invokeCompletionHandler = ((UPnPSoapResponse?, Error?) -> Void)
    
    /**
     url to request
     */
    public var url: URL
    /**
     soap request
     */
    public var soapRequest: UPnPSoapRequest
    /**
     complete handler
     */
    public var completionHandler: (invokeCompletionHandler)?
    
    public init(url: URL, soapRequest: UPnPSoapRequest, completionHandler: (invokeCompletionHandler)?) {
        self.url = url
        self.soapRequest = soapRequest
        self.completionHandler = completionHandler
    }

    /**
     Invoke Action
     */
    public func invoke() {
        let data = soapRequest.xmlDocument.data(using: .utf8)
        var fields = [KeyValuePair]()
        fields.append(KeyValuePair(key: "SOAPACTION", value: "\"\(soapRequest.soapaction)\""))

        HttpClient(url: url, method: "POST", data: data, contentType: "text/xml", fields: fields) {
            (data, response, error) in

            guard error == nil else {
                self.completionHandler?(nil, UPnPError.custom(string: "error - \(error!)"))
                return
            }
            guard getStatusCodeRange(response: response) == .success else {
                self.completionHandler?(nil, HttpError.notSuccess(code: getStatusCode(response: response, defaultValue: 0)))
                return
            }
            guard let data = data else {
                self.completionHandler?(nil, UPnPError.custom(string: "no data"))
                return
            }
            guard let text = String(data: data, encoding: .utf8) else {
                self.completionHandler?(nil, UPnPError.custom(string: "not string"))
                return
            }
            do {
                guard let soapResponse = try UPnPSoapResponse.read(xmlString: text) else {
                    self.completionHandler?(nil, UPnPError.custom(string: "not soap response -- \(text)"))
                    return
                }
                self.completionHandler?(soapResponse, nil)
            } catch {
                self.completionHandler?(nil, UPnPError.custom(string: "\(error)"))
            }

        }.start()
    }
}
