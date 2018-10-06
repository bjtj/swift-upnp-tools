import Foundation
import Socket
import SwiftHttpServer

enum SocketError: Error {
    case select(String)
}

extension DispatchTime {
    public var uptime: UInt64 {
        return uptimeNanoseconds / 1_000_000
    }
}

public class SSDP {

    public static var MCAST_HOST = "239.255.255.250"
    public static var MCAST_PORT = 1900

    public static func sendMsearch(st: String, mx: Int, handler: (((String, Int32)?, SSDPHeader?) -> Void)? = nil) {

        let text = "M-SEARCH * HTTP/1.1\r\n" +
          "HOST: \(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)\r\n" +
          "MAN: \"ssdp:discover\"\r\n" +
          "MX: \(mx)\r\n" +
          "ST: \(st)\r\n" +
          "\r\n"

        do {
            let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            try socket.setReadTimeout(value: UInt(100))
            try socket.setWriteTimeout(value: UInt(100))
            let ssdp_addr = Socket.createAddress(for: SSDP.MCAST_HOST, on: Int32(SSDP.MCAST_PORT))
            try socket.write(from: text.data(using: .utf8)!, to: ssdp_addr!)

            let tick = DispatchTime.now()

            while true {

                let dur = Double(DispatchTime.now().uptime - tick.uptime) / 1_000.0
                if dur >= Double(mx) {
                    break
                }
                
                var readData = Data(capacity: 4096)
                let ret = try socket.readDatagram(into: &readData)
                guard let remote_address = ret.address else {
                    continue
                }
                let header = SSDPHeader.read(text: String(data: readData, encoding: .utf8)!)
                if let handler = handler {
                    let address = Socket.hostnameAndPort(from: remote_address)
                    handler(address, header)
                }
            }

            socket.close()

        } catch let error {
            print("send msearch error -- \(error)")
        }
    }


    public static func notify(properties: OrderedProperties) {

        var text = "NOTIFY * HTTP/1.1\r\n"
        if properties["HOST"] == nil {
            text += "HOST: \(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)\r\n"
        }
        for field in properties.fields {
            text += "\(field.key): \(field.literalValue)\r\n"
        }
        text += "\r\n"
        
        do {
            let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            try socket.setWriteTimeout(value: UInt(100))
            let ssdp_addr = Socket.createAddress(for: SSDP.MCAST_HOST, on: Int32(SSDP.MCAST_PORT))
            try socket.write(from: text.data(using: .utf8)!, to: ssdp_addr!)
            socket.close()
        } catch let error {
            print(error)
        }
    }
}
