//
// UPnPScpdBuilder.swift
//

import Foundation

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
    public var scpdHandler: ((UPnPService, UPnPScpd) -> Void)?
    
    public init(service: UPnPService, scpdHandler: ((UPnPService, UPnPScpd) -> Void)?) {
        self.service = service
        self.scpdHandler = scpdHandler
    }

    /**
     build
     */
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
                print("HttpClient - error: \(error)")
                return
            }
            
            guard let data = data else {
                print("HttpClient - error: no data")
                return
            }

            guard let xmlString = String(data: data, encoding: .utf8) else {
                print("HttpClient - error: xml string failed")
                return
            }

            guard let scpd = UPnPScpd.read(xmlString: xmlString) else {
                print("HttpClient - read scpd failed")
                print(xmlString)
                return
            }

            self.service.scpd = scpd
            
            if let scpdHandler = self.scpdHandler {
                scpdHandler(self.service, scpd)
            }
        }.start()
    }
}
