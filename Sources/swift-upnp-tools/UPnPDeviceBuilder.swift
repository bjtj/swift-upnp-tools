import Foundation

public protocol UPnPDeviceBuilderDelegate {
    func onDeviceBuild(url: URL?, device: UPnPDevice?)
}

public class UPnPDeviceBuilder : HttpClientDelegate {

    public var delegate: UPnPDeviceBuilderDelegate?

    public init(delegate: UPnPDeviceBuilderDelegate?) {
        self.delegate = delegate
    }
    
    public func build(url: URL) {
        HttpClient(url: url, handler: self).start()
    }

    public func onHttpResponse(request: URLRequest, data: Data?, response: URLResponse?) {
        guard let data = data else {
            print("no data")
            return
        }
        guard let xmlString = String(data: data, encoding: .utf8) else {
            print("no xml string")
            return
        }
        guard let device = UPnPDevice.read(xmlString: xmlString) else {
            print("UPnPDevice.read() failed")
            print(xmlString)
            return
        }
        let services = device.allServices
        for service in services {
            UPnPScpdBuilder(service: service).build()
        }
        if let delegate = delegate {
            delegate.onDeviceBuild(url: request.url, device: device)
        }
    }

    public func onError(error: Error?) {
    }
}
