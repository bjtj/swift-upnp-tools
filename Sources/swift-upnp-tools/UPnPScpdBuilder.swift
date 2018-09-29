import Foundation


public class UPnPScpdBuilder : HttpClientDelegate {
    public var service: UPnPService
    public init(service: UPnPService) {
        self.service = service
    }

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
        HttpClient(url: url, handler: self).start()
    }

    public func onHttpResponse(request: URLRequest, data: Data?, response: URLResponse?) {
        guard let data = data else {
            return
        }

        guard let xmlString = String(data: data, encoding: .utf8) else {
            return
        }

        guard let scpd = UPnPScpd.read(xmlString: xmlString) else {
            return
        }

        service.scpd = scpd
    }

    public func onError(error: Error?) {
    }
}
