

public class UPnPModel {
    var props: [String:String] = [:]
    subscript(key: String) -> String? {
        get {
            return props[key]
        }
        set (newValue) {
            props[key] = newValue
        }
    }
}

public class UPnPDevice : UPnPModel {
}

public class UPnPService : UPnPModel {
}

public class UPnPScpd : UPnPModel {
}

public class UPnPAction : UPnPModel {
}

public class UPnPActionArgument : UPnPModel {
}

public class UPnPStateVariable : UPnPModel {
}

