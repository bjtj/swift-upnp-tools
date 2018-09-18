
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
