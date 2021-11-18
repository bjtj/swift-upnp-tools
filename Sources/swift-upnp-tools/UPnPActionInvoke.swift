//
// UPnPActionInvoke.swift
// 

import Foundation

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
    public var completeHandler: ((UPnPSoapResponse?) -> Void)?
    
    public init(url: URL, soapRequest: UPnPSoapRequest, completeHandler: ((UPnPSoapResponse?) -> Void)?) {
        self.url = url
        self.soapRequest = soapRequest
        self.completeHandler = completeHandler
    }

    /**
     Invoke Action
     */
    public func invoke() {
        let data = soapRequest.xmlDocument.data(using: .utf8)
        var fields = [KeyValuePair]()
        fields.append(KeyValuePair(key: "Content-Type", value: "text/xml"))
        fields.append(KeyValuePair(key: "SOAPACTION", value: "\"\(soapRequest.soapaction)\""))
        HttpClient(url: url, method: "POST", data: data, fields: fields) {
            (data, response, error) in
            guard let completeHandler = self.completeHandler else {
                return
            }

            guard error == nil else {
                print("error - \(error!)")
                completeHandler(nil)
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
        }.start()
    }
}
