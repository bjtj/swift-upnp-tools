import Foundation

public func getInetAddress() -> InetAddress? {
    let addrs = getInetAddresses()
    for addr in addrs {
        if addr.hostname != "127.0.0.1" && addr.hostname != "0.0.0.0" {
            return addr
        }
    }
    return nil
}

public func getInetAddresses() -> [InetAddress] {

    var result = [InetAddress]()
    var addrs: UnsafeMutablePointer<ifaddrs>? = nil
    guard getifaddrs(&addrs) == 0 else {
        print("getifaddrs() failed")
        return result
    }

    var ptr = addrs
    while ptr != nil {
        let addr = ptr!.pointee.ifa_addr
        if addr!.pointee.sa_family == AF_INET {
            var addr_in = sockaddr_in()
			memcpy(&addr_in, &(addr!.pointee), Int(MemoryLayout<sockaddr_in>.size))
			let bufLen = Int(INET_ADDRSTRLEN)
			var buf = [CChar](repeating: 0, count: bufLen)
			inet_ntop(Int32(addr_in.sin_family), &addr_in.sin_addr, &buf, socklen_t(bufLen))
            result.append(InetAddress(hostname: String(cString: buf), port: 0))
        } else if addr!.pointee.sa_family == AF_INET6 {
            var addr_in = sockaddr_in6()
			memcpy(&addr_in, &(addr!.pointee), Int(MemoryLayout<sockaddr_in6>.size))
			let bufLen = Int(INET6_ADDRSTRLEN)
			var buf = [CChar](repeating: 0, count: bufLen)
			inet_ntop(Int32(addr_in.sin6_family), &addr_in.sin6_addr, &buf, socklen_t(bufLen))
            result.append(InetAddress(hostname: String(cString: buf), port: 0))
        }
        ptr = ptr!.pointee.ifa_next
    }

    freeifaddrs(addrs)
    return result
}
