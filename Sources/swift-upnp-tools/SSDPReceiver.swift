//
// SSDPReceiver.swift
// 

import Foundation
import Socket

// SSDP Receiver
public class SSDPReceiver {

    // finishing flag
    var finishing: Bool = false

    // SSDP header handler
    public var handler: SSDPHeaderHandler?

    public init(handler: SSDPHeaderHandler? = nil) {
        self.handler = handler
    }

    // Run server
    public func run() throws {
        finishing = false
        let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
        let group = in_addr(s_addr: inet_addr(SSDP.MCAST_HOST))
        let interface = in_addr(s_addr: inet_addr("0.0.0.0"))
        var mreq = ip_mreq(imr_multiaddr: group, imr_interface: interface)
        setsockopt(socket.socketfd, Int32(IPPROTO_IP), IP_ADD_MEMBERSHIP,
                   &mreq, socklen_t(MemoryLayout<ip_mreq>.size))
        while finishing == false {
            var readData = Data(capacity: 4096)
            let ret = try socket.listen(forMessage: &readData, on: SSDP.MCAST_PORT)
            let header = SSDPHeader.read(text: String(data: readData, encoding: .utf8)!)
            
            guard let handler = handler else {
                continue
            }

            let address = Socket.hostnameAndPort(from: ret.address!)
            guard let responseHeaders = handler(address, header) else {
                continue
            }
            
            for responseHeader in responseHeaders {
                let data = responseHeader.description.data(using: .utf8)
                try socket.write(from: data!, to: ret.address!)
            }
        }
        socket.close()
    }

    // Set finishing flag
    public func finish() {
        finishing = true
    }
}
