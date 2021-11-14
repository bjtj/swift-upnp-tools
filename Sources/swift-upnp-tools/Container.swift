// 
// Container.swift
// 

import Foundation


/**
 Key Value Pair
 */
public class KeyValuePair {

    // key
    public var key: String
    // value
    public var value: String
    
    public init (key: String, value: String) {
        self.key = key
        self.value = value
    }

    // equals key ignore case
    func equalsKeyIgnorecase(_ key: String) -> Bool {
        return self.key.caseInsensitiveCompare(key) == .orderedSame
    }

    // equals key
    func equalsKey(_ key: String) -> Bool {
        return self.key.compare(key) == .orderedSame
    }
}

/**
 Ordered Properties
 */
public class OrderedProperties {

    // fields
    public var fields = [KeyValuePair]()

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

/**
 Ordered Case-Insensitive Properties
 */
public class OrderedCaseInsensitiveProperties {

    // fields
    public var fields: [KeyValuePair] = []

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
