import Foundation

public typealias InetAddress = (hostname: String, port: Int32)

func isReadableOrWritable(socketfd: Int32, timeout: UInt) throws -> (readable: Bool, writable: Bool) {

    var readfds = fd_set()
    readfds.zero()
    readfds.set(socketfd)

    var writefds = fd_set()
    writefds.zero()
    writefds.set(socketfd)

    var count: Int32 = 0

    var timer = timeval()

	let secs = Int(Double(timeout / 1000))
	timer.tv_sec = secs

	let msecs = Int32(Double(timeout % 1000))
	let uSecs = msecs * 1000

	#if os(Linux)
	timer.tv_usec = Int(uSecs)
	#else
	timer.tv_usec = Int32(uSecs)
    #endif
    
    count = select(socketfd + Int32(1), &readfds, &writefds, nil, &timer)

    if count < 0 {
        throw SocketError.select("select() failed")
    }

    let readable = readfds.isSet(socketfd)
    let writable = writefds.isSet(socketfd)
    return (readable, writable)
}

struct swift_upnp_tools {
    var text = "Hello, World!"
}
