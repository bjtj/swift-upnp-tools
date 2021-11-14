//
// UPnPScpdBuilder.swift
//

import Foundation

// UPnP Scpd Builder
public class UPnPScpdBuilder {
    
    // UPnP Service
    public var service: UPnPService
    
    public init(service: UPnPService) {
        self.service = service
    }

    // build
    public func build() {
        guard let device = service.device else {
            return
        }
        guard let baseUrl = device.rootDevice.baseUrl else {
            return
        }
        guard let scpdUrl = service.scpdUrl else {
            return
        }
        guard let url = URL(string: scpdUrl, relativeTo: baseUrl) else {
            return
        }
        HttpClient(url: url) {
            (data, response, error) in

            guard error == nil else {
                return
            }
            
            guard let data = data else {
                return
            }

            guard let xmlString = String(data: data, encoding: .utf8) else {
                return
            }

            guard let scpd = UPnPScpd.read(xmlString: xmlString) else {
                return
            }

            self.service.scpd = scpd
        }.start()
    }
}
