//
// UPnPScpdBuilder.swift
//

import Foundation

/**
 UPnP Scpd Builder Delegate
 */
public typealias UPnPScpdBuilderDelegate = (UPnPService?, UPnPScpd?, String?) -> Void

/**
 UPnP Scpd Builder
 */
public class UPnPScpdBuilder {
    
    /**
     UPnP Service
     */
    public var service: UPnPService

    /**
     Scpd Handler
     */
    public var scpdHandler: UPnPScpdBuilderDelegate?
    
    public init(service: UPnPService, scpdHandler: (UPnPScpdBuilderDelegate)?) {
        self.service = service
        self.scpdHandler = scpdHandler
    }

    /**
     build
     */
    public func build() {

        guard let device = service.device else {
            service.buildStatus = .failed
            service.errorString = "service has no device"
            self.scpdHandler?(service, nil, service.errorString)
            return
        }
        guard let baseUrl = device.rootDevice.baseUrl else {
            service.buildStatus = .failed
            service.errorString = "no base url"
            self.scpdHandler?(service, nil, service.errorString)
            return
        }
        guard let scpdUrl = service.scpdUrl else {
            service.buildStatus = .failed
            service.errorString = "no scpd url"
            self.scpdHandler?(service, nil, service.errorString)
            return
        }
        guard let url = URL(string: scpdUrl, relativeTo: baseUrl) else {
            service.buildStatus = .failed
            service.errorString = "url failed"
            self.scpdHandler?(service, nil, service.errorString)
            return
        }
        
        service.buildStatus = .progress
        
        HttpClient(url: url) {
            (data, response, error) in

            guard error == nil else {
                self.service.buildStatus = .failed
                self.service.errorString = "HttpClient - error: '\(error!)'"
                self.scpdHandler?(self.service, nil, self.service.errorString)
                return
            }
            
            guard let data = data else {
                self.service.buildStatus = .failed
                self.service.errorString = "HttpClient - error: no data"
                self.scpdHandler?(self.service, nil, self.service.errorString)
                return
            }

            guard let xmlString = String(data: data, encoding: .utf8) else {
                self.service.buildStatus = .failed
                self.service.errorString = "HttpClient - error: xml string failed"
                self.scpdHandler?(self.service, nil, self.service.errorString)
                return
            }

            guard let scpd = UPnPScpd.read(xmlString: xmlString) else {
                self.service.buildStatus = .failed
                self.service.errorString = "HttpClient - read scpd failed - URL: '\(url)'"
                self.scpdHandler?(self.service, nil, self.service.errorString)
                return
            }

            self.service.scpd = scpd
            self.service.buildStatus = .completed
            self.scpdHandler?(self.service, scpd, nil)
            
        }.start()
    }
}
