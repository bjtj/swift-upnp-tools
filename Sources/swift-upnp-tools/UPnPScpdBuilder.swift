//
// UPnPScpdBuilder.swift
//

import Foundation

/**
 UPnP Scpd Builder Delegate
 */
public typealias scpdBuildCompletionHandler = (UPnPDevice?, UPnPService?, UPnPScpd?, String?) -> Void

/**
 UPnP Scpd Builder
 */
public class UPnPScpdBuilder {

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
    public var completionHandler: scpdBuildCompletionHandler?
    
    public init(device: UPnPDevice, service: UPnPService, completionHandler: (scpdBuildCompletionHandler)?) {
        self.device = device
        self.service = service
        self.completionHandler = completionHandler
    }

    /**
     build
     */
    public func build() {

        guard let device = service.device else {
            service.buildStatus = .failed
            service.errorString = "service has no device"
            self.completionHandler?(nil, service, nil, service.errorString)
            return
        }
        guard let baseUrl = device.rootDevice.baseUrl else {
            service.buildStatus = .failed
            service.errorString = "no base url"
            self.completionHandler?(device, service, nil, service.errorString)
            return
        }
        guard let scpdUrl = service.scpdUrl else {
            service.buildStatus = .failed
            service.errorString = "no scpd url"
            self.completionHandler?(device, service, nil, service.errorString)
            return
        }
        guard let url = URL(string: scpdUrl, relativeTo: baseUrl) else {
            service.buildStatus = .failed
            service.errorString = "url failed"
            self.completionHandler?(device, service, nil, service.errorString)
            return
        }
        
        service.buildStatus = .progress
        
        HttpClient(url: url) {
            (data, response, error) in

            guard error == nil else {
                self.service.buildStatus = .failed
                self.service.errorString = "HttpClient - error: '\(error!)'"
                self.completionHandler?(device, self.service, nil, self.service.errorString)
                return
            }
            
            guard let data = data else {
                self.service.buildStatus = .failed
                self.service.errorString = "HttpClient - error: no data"
                self.completionHandler?(device, self.service, nil, self.service.errorString)
                return
            }

            guard let xmlString = String(data: data, encoding: .utf8) else {
                self.service.buildStatus = .failed
                self.service.errorString = "HttpClient - error: xml string failed"
                self.completionHandler?(device, self.service, nil, self.service.errorString)
                return
            }

            guard let scpd = UPnPScpd.read(xmlString: xmlString) else {
                self.service.buildStatus = .failed
                self.service.errorString = "HttpClient - read scpd failed - URL: '\(url)'"
                self.completionHandler?(device, self.service, nil, self.service.errorString)
                return
            }

            self.service.scpd = scpd
            self.service.buildStatus = .completed
            self.completionHandler?(device, self.service, scpd, nil)
            
        }.start()
    }
}
