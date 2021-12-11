// 
// OrderedProperties.swift
// 

import Foundation

/**
 Ordered Properties
 */
public class OrderedProperties {

    public var fields = [KeyValuePair]()

    public init() {
    }

    public var keys: [String] {
        return fields.map { $0.key }
    }

    func compareKey(_ field: KeyValuePair, _ key: String) -> Bool {
        return field.equalsKey(key)
    }

    public subscript (key: String) -> String? {
        get {
            for field in fields {
                if compareKey(field, key) {
                    return field.value
                }
            }
            return nil
        }
        set(newValue) {

            guard let value = newValue else {
                fields.removeAll { compareKey($0, key) }
                return
            }
            
            for field in fields {
                if compareKey(field, key) {
                    field.value = value
                    return
                }
            }
            fields.append(KeyValuePair(key: key, value: value))
        }
    }
}
