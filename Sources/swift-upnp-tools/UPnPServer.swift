import SwiftHttpServer

public class UPnPServer {

    public var finishing = false
    public var httpServer: HttpServer?
    public var ssdpReceiver: SSDPReceiver?

    public init() {
    }

    func run() {
        finishing = false
    }

    func finish() {
        finishing = true
    }
}
