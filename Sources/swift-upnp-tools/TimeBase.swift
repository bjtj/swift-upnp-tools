//
// TimeBase.swift
// 

import Foundation

/**
 Time based object
 */
public class TimeBase {
    public var tick: DispatchTime
    public var timeout: UInt64

    public init(timeout: UInt64) {
        self.tick = DispatchTime.now()
        self.timeout = timeout
    }

    /**
     Renew timeout
     */
    public func renewTimeout() {
        tick = DispatchTime.now()
    }

    /**
     Duration in Seconds
     */
    public var duration: UInt64 {
        return (DispatchTime.now().uptimeNanoseconds - tick.uptimeNanoseconds) / 1_000_000_000
    }

    /**
     Test if it is expired
     */
    public var isExpired: Bool {
        return duration >= timeout
    }
}
