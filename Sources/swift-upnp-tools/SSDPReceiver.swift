//
// SSDPReceiver.swift
// 

import Foundation
import Socket
import SwiftHttpServer

/**
 SSDP Receiver
 */
public class SSDPReceiver {

    /**
     Listener
     */
    public class Listener: Equatable {
        private var _id = NSUUID().uuidString.lowercased()
        var listener: ssdpListener
        var listeners: [Listener]

        init(_ listeners: [Listener], _ listener: @escaping ssdpListener) {
            self.listeners = listeners
            self.listener = listener
        }

        public static func ==(_ lhs: Listener, _ rhs: Listener) -> Bool {
            return lhs._id == rhs._id
        }

        func remove() {
            self.listeners.removeAll(where: {$0 == self})
        }
    }

    /**
     status
     */
    public enum Status {
        case started, stopped
    }

    /**
     monitoring handler
     */
    public typealias monitoringHandler = ((String?, Status) -> Void)

    var monitorName: String?
    var monitoringHandler: monitoringHandler?

    /**
     SSDP handler
     - Parameter hostname: address (hostname, port)
     - Parameter port: ssdp header
     - Parameter error: error

     - Return ssdp headers to reponse
     */
    public typealias ssdpHandler = (((hostname:String, port: Int32)?, SSDPHeader?, Error?) -> [SSDPHeader]?)

    public typealias ssdpListener = (((hostname:String, port: Int32)?, SSDPHeader?, Error?) -> Void)

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
    
    var handler: ssdpHandler?
    var listenSocket: Socket
    var listeners: [Listener] = []

    public init(handler: SSDPReceiver.ssdpHandler? = nil) throws {
        self.handler = handler
        listenSocket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
    }

    deinit {
        listenSocket.close()
    }

    /**
     set monitor
     */
    public func monitor(name: String?, handler: monitoringHandler?) {
        monitorName = name
        self.monitoringHandler = handler
    }

    /**
     add listener
     */
    public func listener(add listener: @escaping ssdpListener) -> Listener{
        let l = Listener(self.listeners, listener)
        self.listeners.append(l)
        return l
    }

    /**
     Run
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

        self.monitoringHandler?(monitorName, .started)

        defer {
            self.monitoringHandler?(monitorName, .stopped)
        }
        
        while finishing == false {
            var readData = Data(capacity: 4096)
            let ret = try listenSocket.listen(forMessage: &readData, on: SSDP.MCAST_PORT)

            guard ret.bytesRead > 0 else {
                if finishing == false {
                    let err = UPnPError.custom(string: "SSDPReceiver::run() unexpectedly socket closed")
                    let _ = self.handler?(nil, nil, err)
                    throw err
                }
                return
            }

            guard let remoteAddress = ret.address else {
                let err = UPnPError.custom(string: "SSDPReceiver::run() remote address is nil")
                let _ = self.handler?(nil, nil, err)
                throw err
            }

            guard let text = String(data: readData, encoding: .utf8) else {
                continue
            }
            
            let header = SSDPHeader.read(text: text)
            
            guard let handler = self.handler else {
                continue
            }

            let addr = Socket.hostnameAndPort(from: remoteAddress)

            self.listeners.forEach {
                $0.listener(addr, header, nil)
            }

            guard let responseHeaders = handler(addr, header, nil) else {
                continue
            }
            
            for responseHeader in responseHeaders {
                guard let data = responseHeader.description.data(using: .utf8) else {
                    continue
                }
                try listenSocket.write(from: data, to: remoteAddress)
            }
        }
        listenSocket.close()
    }

    /**
     Set finish
     */
    public func finish() {
        finishing = true
        listenSocket.close()
    }
}
