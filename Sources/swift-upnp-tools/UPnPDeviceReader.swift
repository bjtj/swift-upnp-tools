import Foundation

public protocol OnDeviceBuildProtocol {
    func onDeviceBuild(url: URL?, device: UPnPDevice?)
}

public func buildDevice(url: URL, deviceHandler: OnDeviceBuildProtocol?) {

    class Delegate: HttpClientDelegate {
        let url: URL
        let deviceHandler: OnDeviceBuildProtocol?
        init(url: URL, deviceHandler: OnDeviceBuildProtocol?) {
            self.url = url
            self.deviceHandler = deviceHandler
        }
        func onHttpResponse(data: Data?, response: URLResponse?) {
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
            // let services = device.allServices
            // for service in services {
            // }
            if let deviceHandler = deviceHandler {
                deviceHandler.onDeviceBuild(url: url, device: device)
            }
        }
        func onError(error: Error?) {
        }
    }

    HttpClient(url: url, handler: Delegate(url: url, deviceHandler: deviceHandler)).start()
    
}
