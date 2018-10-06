import Foundation


public class UPnPScpdBuilder {
    public var service: UPnPService
    public init(service: UPnPService) {
        self.service = service
    }

    public func build() {
        guard let url = service.scpdUrlFull else {
            print("scpd url full -- failed")
            return
        }

        print("url -- \(url)")

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
                print("not xml string")
                return
            }

            guard let scpd = UPnPScpd.read(xmlString: xmlString) else {
                print("read scpd -- failed")
                return
            }

            print("set scpd")
            self.service.scpd = scpd
        }.start()
    }
}
