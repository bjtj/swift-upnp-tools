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
     user agent
     */
    public var userAgent: String? = nil
    
    /**
     complete handler
     */
    public var completionHandler: (invokeCompletionHandler)?
    
    public init(url: URL, soapRequest: UPnPSoapRequest, userAgent: String? = nil, completionHandler: (invokeCompletionHandler)?) {
        self.url = url
        self.soapRequest = soapRequest
        self.userAgent = userAgent
        self.completionHandler = completionHandler
    }

    /**
     Invoke Action
     */
    public func invoke() {
        guard let data = soapRequest.xmlDocument.data(using: .utf8) else {
            print("UPnPActionInvoke::invoke() failed - xml data to utf8")
            return
        }
        var fields = [KeyValuePair]()
        if let userAgent = self.userAgent {
            fields.append(KeyValuePair(key: "USER-AGENT", value: "\"\(userAgent)\""))
        }
        fields.append(KeyValuePair(key: "SOAPACTION", value: "\"\(soapRequest.soapaction)\""))

        HttpClient(url: url, method: "POST", data: data, contentType: "text/xml", fields: fields) {
            (data, response, error) in

            guard error == nil else {
                self.completionHandler?(nil, UPnPError.custom(string: "error - \(error!)"))
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

            guard getStatusCodeRange(response: response) == .success else {
                guard let errorResponse = try? UPnPSoapErrorResponse.read(xmlString: text) else {
                    self.completionHandler?(nil, HttpError.notSuccess(code: getStatusCode(response: response, defaultValue: 0)))
                    return
                }

                guard let err = UPnPActionError(rawValue: errorResponse.errorCode), err.rawValue == UPnPActionError.custom(errorResponse.errorCode, errorResponse.errorDescription).rawValue else {
                    self.completionHandler?(nil, UPnPActionError.custom(errorResponse.errorCode, errorResponse.errorDescription))
                    return
                }

                self.completionHandler?(nil, err)
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
