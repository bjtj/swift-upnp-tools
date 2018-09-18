
public class KeyValuePair {

    public var key: String
    public var value: String
    
    init (key: String, value: String) {
        self.key = key
        self.value = value
    }

    func equalsKeyIgnorecase(_ key: String) -> Bool {
        return self.key.caseInsensitiveCompare(key) == .orderedSame
    }

    func equalsKey(_ key: String) -> Bool {
        return self.key.compare(key) == .orderedSame
    }
}


public class OrderedProperties {
    public var fields: [KeyValuePair] = []

    subscript (key: String) -> String? {
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

public class OrderedCaseInsensitiveProperties {
    public var fields: [KeyValuePair] = []

    subscript (key: String) -> String? {
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
