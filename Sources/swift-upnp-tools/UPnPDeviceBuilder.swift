import Foundation


public class UPnPDeviceBuilder {

    public var delegate: ((UPnPDevice?) -> Void)?

    public init(delegate: ((UPnPDevice?) -> Void)?) {
        self.delegate = delegate
    }
    
    public func build(url: URL) {
        HttpClient(url: url) {
            (data, response, error) in
            guard error == nil else {
                print("error - \(error!)")
                return
            }
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
            device.baseUrl = url
            let services = device.allServices
            for service in services {
                UPnPScpdBuilder(service: service).build()
            }
            if let delegate = self.delegate {
                delegate(device)
            }
        }.start()
    }
}
