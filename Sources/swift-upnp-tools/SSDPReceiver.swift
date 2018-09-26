import Foundation
import Socket

public class SSDPReceiver {

    var finishing: Bool = false
    public var handler: SSDPHandlerClosure?

    public init(handler: SSDPHandlerClosure? = nil) {
        self.handler = handler
    }

    public func run() throws {
        finishing = false
        let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
        var readData = Data(capacity: 4096)
        let group = in_addr(s_addr: inet_addr(SSDP.MCAST_HOST))
        let interface = in_addr(s_addr: inet_addr("0.0.0.0"))
        var mreq = ip_mreq(imr_multiaddr: group, imr_interface: interface)
        setsockopt(socket.socketfd, Int32(IPPROTO_IP), IP_ADD_MEMBERSHIP,
                   &mreq, socklen_t(MemoryLayout<ip_mreq>.size))
        while finishing == false {
            let ret = try socket.listen(forMessage: &readData, on: SSDP.MCAST_PORT)
            let header = SSDPHeader.read(text: String(data: readData, encoding: .utf8)!)
            if let handler = handler {
                if let responseHeaders = handler(header) {
                    for responseHeader in responseHeaders {
                        let data = responseHeader.description.data(using: .utf8)
                        try socket.write(from: data!, to: ret.address!)
                    }
                }
            }
        }
        socket.close()
    }

    public func finish() {
        finishing = true
    }
}
