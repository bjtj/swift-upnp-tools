import Foundation
import Socket

enum SocketError: Error {
    case select(String)
}

public class SSDP {

    public static var MCAST_HOST = "239.255.255.250"
    public static var MCAST_PORT = 1900

    public static func sendMsearch(st: String, mx: Int, handler: ((InetAddress?, SSDPHeader?) -> Void)? = nil) {

        let text = "M-SEARCH * HTTP/1.1\r\n" +
          "HOST: \(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)\r\n" +
          "MAN: \"ssdp:discover\"\r\n" +
          "MX: \(mx)\r\n" +
          "ST: \(st)\r\n" +
          "\r\n"

        do {
            let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            try socket.setWriteTimeout(value: UInt(100))
            let ssdp_addr = Socket.createAddress(for: SSDP.MCAST_HOST, on: Int32(SSDP.MCAST_PORT))
            try socket.write(from: text.data(using: .utf8)!, to: ssdp_addr!)

            let tick = DispatchTime.now()

            while true {

                let dur = (DispatchTime.now().uptimeNanoseconds - tick.uptimeNanoseconds) / 1_000_000_000
                if dur >= mx {
                    break
                }

                guard try isReadableOrWritable(socketfd: socket.socketfd, timeout: 1_000).0 == true else {
                    continue
                }
                
                var readData = Data(capacity: 4096)
                let ret = try socket.readDatagram(into: &readData)
                let header = SSDPHeader.read(text: String(data: readData, encoding: .utf8)!)
                if let handler = handler {
                    let address = Socket.hostnameAndPort(from: ret.address!)
                    handler(address, header)
                }
            }

            socket.close()

        } catch let error {
            print(error)
        }
    }


    public static func notify(properties: OrderedProperties) {

        var text = "NOTIFY * HTTP/1.1\r\n"
        if properties["HOST"] == nil {
            text += "HOST: \(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)\r\n"
        }
        for field in properties.fields {
            text += "\(field.key): \(field.value)\r\n"
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
