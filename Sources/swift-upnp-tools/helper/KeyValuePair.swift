//
// KeyValuePair.swift
// 

import Foundation


/**
 Key Value Pair
 */
public class KeyValuePair {

    public var key: String
    public var value: String
    
    public init (key: String, value: String) {
        self.key = key
        self.value = value
    }

    /**
     equals key ignore case
     */
    func equalsKeyIgnorecase(_ key: String) -> Bool {
        return self.key.caseInsensitiveCompare(key) == .orderedSame
    }

    /**
     equals key
     */
    func equalsKey(_ key: String) -> Bool {
        return self.key.compare(key) == .orderedSame
    }
}
