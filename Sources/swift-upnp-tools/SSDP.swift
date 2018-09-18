import Foundation
import Socket

public class SSDP {
    static var MCAST_HOST = "239.255.255.250"
    static var MCAST_PORT = 1900
}

func sendMsearch(st: String?, mx: Int, handler: ((SSDPHeader?) -> Void)?) {

    let text = "M-SEARCH * HTTP/1.1\r\n" +
      "HOST: \(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)\r\n" +
      "MAN: \"ssdp:discover\"\r\n" +
      "MX: \(mx)\r\n" +
      "ST: \(st!)\r\n" +
      "\r\n"

    var socket: Socket? = nil
    do {
        try socket = Socket.create(family: .inet, type: .datagram, proto: .udp)
        try socket?.setWriteTimeout(value: UInt(300))
        let ssdp_addr = Socket.createAddress(for: SSDP.MCAST_HOST, on: Int32(SSDP.MCAST_PORT))
        try socket?.write(from: text.data(using: .utf8)!, to: ssdp_addr!)

        let tick = DispatchTime.now()

        while true {

            let dur = (DispatchTime.now().uptimeNanoseconds - tick.uptimeNanoseconds) / 1_000_000_000
            if dur >= mx {
                break
            }
            
            if try socket?.isReadableOrWritable(timeout: 1_000).0 == true {
                var readData = Data(capacity: 4096)
                let _ = try socket?.readDatagram(into: &readData)
                let header = SSDPHeader.read(text: String(data: readData, encoding: .utf8)!)
                if let _handler = handler {
                    _handler(header)
                }
            }
        }

    } catch {
    }

    socket?.close()
}
