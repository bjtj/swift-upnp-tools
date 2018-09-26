
public typealias SSDPHandlerClosure = (SSDPHeader?) -> [SSDPHeader]?

public protocol SSDPHandlerProtocol {
    func onSSDPHeader(ssdpHeader: SSDPHeader) -> [SSDPHeader]?
}

public class SSDPHandler: SSDPHandlerProtocol {
    public var handler: SSDPHandlerClosure?
    public init(handler: SSDPHandlerClosure? = nil) {
        self.handler = handler
    }

    public func onSSDPHeader(ssdpHeader: SSDPHeader) -> [SSDPHeader]? {
        guard let handler = handler else {
            return nil
        }
        return handler(ssdpHeader)
    }
}
