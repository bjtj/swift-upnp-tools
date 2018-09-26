import Foundation

public class TimeBase {
    public var tick: DispatchTime
    public var timeout: UInt64

    public init(timeout: UInt64) {
        self.tick = DispatchTime.now()
        self.timeout = timeout
    }

    public func renewTimeout() {
        tick = DispatchTime.now()
    }

    public var duration: UInt64 {
        return (DispatchTime.now().uptimeNanoseconds - tick.uptimeNanoseconds) / 1_000_000_000
    }

    public var isExpired: Bool {
        return duration >= timeout
    }
}
