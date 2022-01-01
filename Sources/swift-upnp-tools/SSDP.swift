//
// SSDP.swift
// 

import Foundation
import Socket
import SwiftHttpServer


/**
 DispatchTime extension uptime
 */
extension DispatchTime {
    public var uptime: UInt64 {
        return uptimeNanoseconds / 1_000_000
    }
}

/**
 SSDP implmentation
 */
public class SSDP {

    /**
     Multicast hostname
     */
    public static var MCAST_HOST = "239.255.255.250"
    
    /**
     Multicast port
     */
    public static var MCAST_PORT = 1900

    /**
     Send m-search
     - Parameter st: service type
     - Parameter mx: max timeout
     - Parameter handler: ssdp handler
     */
    public static func sendMsearch(st: String, mx: Int, bufferSize: Int = 4096, handler: (SSDPReceiver.ssdpHandler)? = nil) {

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
            guard let ssdp_addr = Socket.createAddress(for: SSDP.MCAST_HOST, on: Int32(SSDP.MCAST_PORT)) else {
                throw UPnPError.custom(string: "Socket.createAddress failed")
            }
            guard let data = text.data(using: .utf8) else {
                throw UPnPError.custom(string: "text.data(using: .utf8) failed")
            }
            try socket.write(from: data, to: ssdp_addr)

            let tick = DispatchTime.now()

            while true {

                let dur = Double(DispatchTime.now().uptime - tick.uptime) / 1_000.0
                if dur >= Double(mx) {
                    break
                }
                var readData = Data(capacity: bufferSize)
                let ret = try socket.readDatagram(into: &readData)
                guard let remote_address = ret.address else {
                    continue
                }
                guard let str = String(data: readData, encoding: .utf8) else {
                    continue
                }
                guard let header = SSDPHeader.read(text: str) else {
                    continue
                }
                if let handler = handler {
                    let address = Socket.hostnameAndPort(from: remote_address)
                    let _ = handler(address, header, nil)
                }
            }

            socket.close()

        } catch let error {
            print("send msearch error -- \(error)")
        }
    }

    /**
     Notify
     */
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
            guard let ssdp_addr = Socket.createAddress(for: SSDP.MCAST_HOST, on: Int32(SSDP.MCAST_PORT)) else {
                throw UPnPError.custom(string: "Socket.createAddress failed")
            }
            guard let data = text.data(using: .utf8) else {
                throw UPnPError.custom(string: "text.data(using: .utf8) failed")
            }
            
            try socket.write(from: data, to: ssdp_addr)
            socket.close()
        } catch let error {
            print(error)
        }
    }
}
