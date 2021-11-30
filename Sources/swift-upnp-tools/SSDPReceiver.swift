//
// SSDPReceiver.swift
// 

import Foundation
import Socket

/**
 SSDP Receiver
 */
public class SSDPReceiver {

    var finishing: Bool = false

    /**
     is running
     */
    public var running: Bool {
        get {
            return _running
        }
    }
    var _running: Bool = false

    /**
     SSDP header handler
     */
    public var handler: SSDPHeaderHandler?

    var listenSocket: Socket

    public init?(handler: SSDPHeaderHandler? = nil) throws {
        self.handler = handler
        listenSocket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
    }

    deinit {
        listenSocket.close()
    }

    /**
     Run server
     */
    public func run() throws {
        if _running {
            print("SSDPReceiver::run() already running")
            return
        }

        defer {
            _running = false
        }
        
        finishing = false
        _running = true
        let group = in_addr(s_addr: inet_addr(SSDP.MCAST_HOST))
        let interface = in_addr(s_addr: inet_addr("0.0.0.0"))
        var mreq = ip_mreq(imr_multiaddr: group, imr_interface: interface)
        setsockopt(listenSocket.socketfd, Int32(IPPROTO_IP), IP_ADD_MEMBERSHIP,
                   &mreq, socklen_t(MemoryLayout<ip_mreq>.size))
        while finishing == false {
            var readData = Data(capacity: 4096)
            let ret = try listenSocket.listen(forMessage: &readData, on: SSDP.MCAST_PORT)

            guard ret.bytesRead > 0 else {
                if finishing == false {
                    throw UPnPError.custom(string: "SSDPReceiver::run() unexpectedly socket closed")
                }
                return
            }
            
            let header = SSDPHeader.read(text: String(data: readData, encoding: .utf8)!)
            
            guard let handler = handler else {
                continue
            }

            guard let addr = ret.address else {
                throw UPnPError.custom(string: "SSDPReceiver::run() remote address is nil")
            }

            let address = Socket.hostnameAndPort(from: addr)
            guard let responseHeaders = handler(address, header) else {
                continue
            }
            
            for responseHeader in responseHeaders {
                let data = responseHeader.description.data(using: .utf8)
                try listenSocket.write(from: data!, to: ret.address!)
            }
        }
        listenSocket.close()
    }

    /**
     Set finishing flag
     */
    public func finish() {
        finishing = true
        listenSocket.close()
    }
}
