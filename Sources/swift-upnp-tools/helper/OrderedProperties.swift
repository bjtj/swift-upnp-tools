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

    public subscript (key: String) -> String? {
        get {
            for field in fields {
                if field.equalsKey(key) {
                    return field.value
                }
            }
            return nil
        }
        set(newValue) {
            for field in fields {
                if field.equalsKey(key) {
                    field.value = newValue!
                    return
                }
            }
            fields.append(KeyValuePair(key: key, value: newValue!))
        }
    }
}
