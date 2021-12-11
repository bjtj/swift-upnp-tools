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

    public var keys: [String] {
        return fields.map { $0.key }
    }

    public init() {
    }

    func compareKey(_ field: KeyValuePair, _ key: String) -> Bool {
        return field.equalsKeyIgnorecase(key)
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
                fields.removeAll(where: { compareKey($0, key) })
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
