import Foundation

public func buildDevice(location: URL, handler: ((UPnPDevice?) -> Void)?) {
    let config = URLSessionConfiguration.default
    let session = URLSession(configuration: config)
    let request = URLRequest(url: location)
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
            handler(device)
        }
    }
    task.resume()
}
