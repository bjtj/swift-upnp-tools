

public class UPnPModel : OrderedProperties {
}


public class UPnPSpecVersion : UPnPModel {
    public var major: String? {
        get { return self["major"] }
        set(value) { self["major"] = value }
    }
    public var minor: String? {
        get { return self["minor"] }
        set(value) { self["minor"] = value }
    }
}


public class UPnPDevice : UPnPModel {
    public var udn: String? {
        get { return self["UDN"] }
        set(value) { self["UDN"] = value }
    }
    public var friendlyName: String? {
        get { return self["friendlyName"] }
        set(value) { self["friendlyName"] = value }
    }
}

public class UPnPService : UPnPModel {
    public var serviceId: String? {
        get { return self["serviceId"] }
        set(value) { self["serviceId"] = value }
    }
    public var serviceType: String? {
        get { return self["serviceType"] }
        set(value) { self["serviceType"] = value }
    }
    public var spcdurl: String? {
        get { return self["SCPDURL"] }
        set(value) { self["SCPDURL"] = value }
    }
    public var controlUrl: String? {
        get { return self["controlURL"] }
        set(value) { self["controlURL"] = value }
    }
    public var evnetSubUrl: String? {
        get { return self["eventSubURL"] }
        set(value) { self["eventSubURL"] = value }
    }
}

public class UPnPScpd : UPnPModel {
    public var actions: [UPnPAction] = []
    public var stateVariables: [UPnPStateVariable] = []
}

public class UPnPAction : UPnPModel {

    public var arguments: [UPnPActionArgument] = []
    
    public var name: String? {
        get { return self["name"] }
        set(value) { self["name"] = value }
    }
}

public class UPnPActionArgument : UPnPModel {
    public var name: String? {
        get { return self["name"] }
        set(value) { self["name"] = value }
    }
}

public class UPnPStateVariable : UPnPModel {
    public var name: String? {
        get { return self["name"] }
        set(value) { self["name"] = value }
    }
}

