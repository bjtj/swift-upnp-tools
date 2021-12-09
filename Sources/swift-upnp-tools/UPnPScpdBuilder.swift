//
// UPnPScpdBuilder.swift
//

import Foundation

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
    
    public init(device: UPnPDevice, service: UPnPService, completionHandler: (completionHandler)?) {
        self.device = device
        self.service = service
        self.completionHandler = completionHandler
    }

    /**
     build
     */
    public func build() {

        guard let device = service.device else {
            handleError(string: "service has no device")
            return
        }
        guard let baseUrl = device.rootDevice.baseUrl else {
            handleError(string: "no base url")
            return
        }
        guard let scpdUrl = service.scpdUrl else {
            handleError(string: "no scpd url")
            return
        }
        guard let url = URL(string: scpdUrl, relativeTo: baseUrl) else {
            handleError(string: "url failed")
            return
        }
        
        service.status = .progress
        
        HttpClient(url: url) {
            (data, response, error) in

            guard error == nil else {
                self.handleError(string: "HttpClient - error: '\(error!)'")
                return
            }
            
            guard let data = data else {
                self.handleError(string: "HttpClient - error: no data")
                return
            }

            guard let xmlString = String(data: data, encoding: .utf8) else {
                self.handleError(string: "HttpClient - error: xml string failed")
                return
            }

            guard let scpd = UPnPScpd.read(xmlString: xmlString) else {
                self.handleError(string: "HttpClient - read scpd failed - URL: '\(url)'")
                return
            }
            
            self.handleCompleted(scpd: scpd)
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
