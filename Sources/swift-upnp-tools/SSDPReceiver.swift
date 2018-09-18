import Foundation
import Socket

public class SSDPReceiver {

    var finishing: Bool = false
    var handler: ((SSDPHeader?) -> [SSDPHeader?])?

    public init(handler: ((SSDPHeader?) -> [SSDPHeader?])?) {
        self.handler = handler
    }

    public func run() {
        finishing = false
        do {
            var socket: Socket? = nil
            try socket = Socket.create(family: .inet, type: .datagram, proto: .udp)

            var readData = Data(capacity: 4096)
            let group = in_addr(s_addr: inet_addr(SSDP.MCAST_HOST))
            let interface = in_addr(s_addr: inet_addr("0.0.0.0"))
            var mreq = ip_mreq(imr_multiaddr: group, imr_interface: interface)
            setsockopt((socket?.socketfd)!, Int32(IPPROTO_IP), IP_ADD_MEMBERSHIP,
                       &mreq, socklen_t(MemoryLayout<ip_mreq>.size))

            while finishing == false {
                let _ = try socket?.listen(forMessage: &readData, on: SSDP.MCAST_PORT)
                let header = SSDPHeader.read(text: String(data: readData, encoding: .utf8)!)
                if let _handler = handler {
                    let responses = _handler(header)
                    for _ in responses {
                        // send back response
                    }
                }
            }
            socket?.close()
        } catch {
        }
    }

    public func finish() {
        finishing = true
    }
}
