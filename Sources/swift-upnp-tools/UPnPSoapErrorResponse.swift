//
// UPnPSoapResponse.swift
// 

import SwiftXml

/**
 UPnP Soap Error Response
 */
public class UPnPSoapErrorResponse : UPnPModel {

    /**
     error code
     */
    public var errorCode: Int

    /**
     error description
     */
    public var errorDescription: String

    public init(errorCode: Int, errorDescription: String) {
        self.errorCode = errorCode
        self.errorDescription = errorDescription
    }

    public convenience init(error: UPnPActionError) {
        self.init(errorCode: error.rawValue.code, errorDescription: error.rawValue.description)
    }

    /**
     read from xml string
     */
    public static func read(xmlString: String) throws -> UPnPSoapErrorResponse {
        let document = try XmlParser.parse(xmlString: xmlString)
        guard let root = document.rootElement else {
            throw UPnPError.readFailed(string: "UPnPSoaErrorpResponse::read() error -- no root")
        }
        guard let elements = root.elements, elements.isEmpty == false else {
            throw UPnPError.readFailed(string: "UPnPSoaErrorpResponse::read() error -- no element")
        }

        guard let name = elements[0].name, name == "Body" else {
            throw UPnPError.readFailed(string: "UPnPSoaErrorpResponse::read() error -- NO BODY TAG")
        }

        guard let bodyElements = elements[0].elements, bodyElements.isEmpty == false else {
            throw UPnPError.readFailed(string: "UPnPSoapErrorResponse::read() error -- empty faultElement")
        }

        let faultElement = bodyElements[0]

        guard let faultElements = faultElement.elements, faultElements.count == 3 else {
            throw UPnPError.readFailed(string: "UPnPSoapErrorResponse::read() error -- invalid format")
        }

        guard faultElements[0].name == "faultcode" && faultElements[1].name == "faultstring" && faultElements[2].name == "detail" else {
            throw UPnPError.readFailed(string: "UPnPSoapErrorResponse::read() error -- invalid format")
        }

        let detailElement = faultElements[2]

        guard let detailElements = detailElement.elements, detailElements.isEmpty == false else {
            throw UPnPError.readFailed(string: "UPnPSoapErrorResponse::read() error -- invalid format")
        }

        let upnpErrorElement = detailElements[0]

        guard let upnpErrorElements = upnpErrorElement.elements, upnpErrorElements.isEmpty == false else {
            throw UPnPError.readFailed(string: "UPnPSoapErrorResponse::read() error -- invalid format")
        }

        guard upnpErrorElements[0].name == "errorCode" && upnpErrorElements[1].name == "errorDescription" else {
            throw UPnPError.readFailed(string: "UPnPSoapErrorResponse::read() error -- invalid format")
        }

        guard let errorCodeString = upnpErrorElements[0].firstText?.text, let errorDescription = upnpErrorElements[1].firstText?.text else {
            throw UPnPError.readFailed(string: "UPnPSoapErrorResponse::read() error -- invalid format")
        }

        guard let errorCode = Int(errorCodeString) else {
            throw UPnPError.readFailed(string: "UPnPSoapErrorResponse::read() error -- invalid format")
        }
        
        return UPnPSoapErrorResponse(errorCode: errorCode, errorDescription: errorDescription)
    }

    /**
     get xml document
     */
    public var xmlDocument: String {
        return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n\(self.description)"
    }

    public var description: String {
        let ext = "xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" " +
          "s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\""
        
        let root = XmlTag(namespace: "s", name: "Envelope", ext: ext, content: "")
        let body = XmlTag(namespace: "s", name: "Body", content: "")
        let fault = XmlTag(namespace: "s", name: "Fault", content: "")
        let faultCode = XmlTag(name: "faultcode", content:"s:Client")
        let faultString = XmlTag(name: "faultstring", content:"UPnPError")
        let uPnPError = XmlTag(name: "UPnPError", ext: "xmlns=\"urn:schemas-upnp-org:control-1-0\"", content: "")
        let errorCode = XmlTag(name: "errorCode", text: "\(self.errorCode)")
        let errorDescrition = XmlTag(name: "errorDescription", text: self.errorDescription)
        
        uPnPError.content = errorCode.description + errorDescrition.description
        let detail = XmlTag(name: "detail", content: uPnPError.description)
        fault.content = faultCode.description + faultString.description + detail.description
        body.content = fault.description
        root.content = body.description
        return root.description
    }
}
