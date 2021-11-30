// 
// OrderedCaseInsensitiveProperties.swift
// 

import Foundation

/**
 Ordered Case-Insensitive Properties
 */
public class OrderedCaseInsensitiveProperties {

    /**
     fields
     */
    public var fields: [KeyValuePair] = []

    public init() {
    }

    public subscript (key: String) -> String? {
        get {
            for field in fields {
                if field.equalsKeyIgnorecase(key) {
                    return field.value
                }
            }
            return nil
        }
        set(newValue) {
            for field in fields {
                if field.equalsKeyIgnorecase(key) {
                    field.value = newValue!
                    return
                }
            }
            fields.append(KeyValuePair(key: key, value: newValue!))
        }
    }
}
