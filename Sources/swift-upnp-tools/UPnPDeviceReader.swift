import Foundation

public protocol OnDeviceBuildProtocol {
    func onDeviceBuild(url: URL?, device: UPnPDevice?)
}

public func buildDevice(url: URL, handler: OnDeviceBuildProtocol?) {
    let config = URLSessionConfiguration.default
    let session = URLSession(configuration: config)
    let request = URLRequest(url: url)
    let task = session.dataTask(with: request) {
        (data, response, error) in

        guard error == nil else {
            print("error - \(error!)")
            return
        }

        guard let data = data else {
            print("error - no data in response")
            return
        }

        guard let text = String(data: data, encoding: .utf8) else {
            print("error - data is not string")
            return
        }
        
        let device = UPnPDevice.read(xmlString: text)
        if let handler = handler {
            handler.onDeviceBuild(url: url, device: device)
        }
    }
    task.resume()
}
