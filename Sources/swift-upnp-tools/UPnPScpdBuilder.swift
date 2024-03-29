//
// UPnPScpdBuilder.swift
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/**
 UPnP Scpd Builder
 */
public class UPnPScpdBuilder {

    /**
     UPnP Scpd Builder Delegate
     - Parameter device
     - Parameter service
     - Parameter scpd
     - Parameter error
     */
    public typealias completionHandler = (UPnPDevice?, UPnPService?, UPnPScpd?, Error?) -> Void

    /**
     UPnP Device
     */
    public var device: UPnPDevice
    
    /**
     UPnP Service
     */
    public var service: UPnPService

    /**
     Scpd Handler
     */
    public var completionHandler: completionHandler?

    /**
     user agent
     */
    public var userAgent: String? = nil
    
    public init(device: UPnPDevice, service: UPnPService, userAgent: String? = nil, completionHandler: (completionHandler)?) {
        self.device = device
        self.service = service
        self.userAgent = userAgent
        self.completionHandler = completionHandler
    }

    /**
     build
     */
    public func build() {

        guard let device = service.device else {
            handleError(string: "UPnPScpdBuilder::build() error - service has no device")
            return
        }
        guard let baseUrl = device.rootDevice.baseUrl else {
            handleError(string: "UPnPScpdBuilder::build() error - no base url")
            return
        }
        guard let scpdUrl = service.scpdUrl else {
            handleError(string: "UPnPScpdBuilder::build() error - no scpd url")
            return
        }
        guard let url = URL(string: scpdUrl, relativeTo: baseUrl) else {
            handleError(string: "UPnPScpdBuilder::build() error - url failed")
            return
        }
        
        service.status = .progress

        var fields = [KeyValuePair]()
        if let userAgent = self.userAgent {
            fields.append(KeyValuePair(key: "USER-AGENT", value: userAgent))
        }
        
        HttpClient(url: url, fields: fields) {
            (data, response, error) in

            guard error == nil else {
                self.handleError(string: "UPnPScpdBuilder::build() error - '\(error!)'")
                return
            }
            
            guard getStatusCodeRange(response: response) == .success else {
                let x = data == nil ? "" : String(data: data!, encoding: .utf8)
                self.handleError(string: "UPnPScpdBuilder::build() error - status code: \(getStatusCode(response: response, defaultValue: 0)) / \(x ?? "")")
                return
            }
            
            guard let data = data else {
                self.handleError(string: "UPnPScpdBuilder::build() error - no data")
                return
            }

            guard let xmlString = String(data: data, encoding: .utf8) else {
                self.handleError(string: "UPnPScpdBuilder::build() error - xml string failed")
                return
            }

            do {
                guard let scpd = try UPnPScpd.read(xmlString: xmlString) else {
                    self.handleError(string: "UPnPScpdBuilder::build() error - read scpd failed")
                    return
                }
                
                self.handleCompleted(scpd: scpd)

            } catch {
                self.handleError(string: "UPnPScpdBuilder::build() error - \(error)")
            }
        }.start()
    }
    
    func handleError(string: String) {
        service.status = .failed
        service.error = UPnPError.custom(string: string)
        self.completionHandler?(device, service, nil, service.error)
    }
    
    func handleCompleted(scpd: UPnPScpd) {
        service.scpd = scpd
        service.status = .completed
        self.completionHandler?(device, service, scpd, nil)
    }
}
