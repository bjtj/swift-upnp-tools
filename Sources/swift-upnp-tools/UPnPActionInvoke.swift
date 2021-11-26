//
// UPnPActionInvoke.swift
// 

import Foundation

public typealias UPnPActionInvokeDelegate = ((UPnPSoapResponse?, String?) -> Void)

/**
 UPnP Action Invoke
 */
public class UPnPActionInvoke {
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
    public var completionHandler: (UPnPActionInvokeDelegate)?
    
    public init(url: URL, soapRequest: UPnPSoapRequest, completionHandler: (UPnPActionInvokeDelegate)?) {
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
                self.completionHandler?(nil, "error - \(error!)")
                return
            }
            guard let data = data else {
                self.completionHandler?(nil, "no data")
                return
            }
            guard let text = String(data: data, encoding: .utf8) else {
                self.completionHandler?(nil, "not string")
                return
            }
            guard let soapResponse = UPnPSoapResponse.read(xmlString: text) else {
                self.completionHandler?(nil, "not soap response -- \(text)")
                return
            }
            self.completionHandler?(soapResponse, nil)

        }.start()
    }
}
