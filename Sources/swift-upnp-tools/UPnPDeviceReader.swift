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

    
    // let config = URLSessionConfiguration.default
    // let session = URLSession(configuration: config)
    // let request = URLRequest(url: url)
    // let task = session.dataTask(with: request) {
    //     (data, response, error) in

    //     guard error == nil else {
    //         print("error - \(error!)")
    //         return
    //     }

    //     guard let data = data else {
    //         print("error - no data in response")
    //         return
    //     }

    //     guard let text = String(data: data, encoding: .utf8) else {
    //         print("error - data is not string")
    //         return
    //     }
        
    //     let device = UPnPDevice.read(xmlString: text)
    //     let services = device.allServices
    //     for service in services {
    //         // 
    //     }
    //     if let handler = handler {
    //         handler.onDeviceBuild(url: url, device: device)
    //     }
    // }
    // task.resume()
}
