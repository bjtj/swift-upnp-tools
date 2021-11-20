import Foundation
import SwiftUpnpTools

struct Session {
    var device: UPnPDevice?
    var service: UPnPService?
}

func main() {

    var session = Session()

    var done = false

    let cp = UPnPControlPoint(httpServerBindPort: 0)
    cp.run()

    cp.onDeviceAdded {
        (device) in
        print("-*- [ADDED] \(device.friendlyName ?? "nil") (UDN: \(device.udn ?? "nil"))")
    }

    cp.onDeviceRemoved {
        (device) in
        print("-*- [REMOVED] \(device.friendlyName ?? "nil") (UDN: \(device.udn ?? "nil"))")
    }

    cp.onEventProperty {
        (sid, properties) in
        print("-*- EVENT NOTIFY -- (SID: \(sid))")
        for field in properties.fields {
            print("  - \(field.key): \(field.value)")
        }
    }

    while done == false {
        guard let line = readLine() else {
            continue
        }
        let tokens = line.split(separator: " ", maxSplits: 1).map { String($0) }
        guard tokens.isEmpty == false else {
            print(" -== SESSION ==-")
            guard let device = session.device else {
                print("[ERR] Device is not selected")
                continue
            }
            print("[Device] -- \(device.udn ?? "nil") \(device.friendlyName ?? "nil")")
            guard let service = session.service else {
                print("[ERR] Service is not selected")
                continue
            }
            print("[Service] -- \(service.serviceType ?? "nil")")
            continue
        }
        switch tokens[0] {
        case "quit", "q":
            done = true
            break
        case "search":
            handleSearch(cp: cp, st: tokens[1])
        case "ls":
            print(" == Device List (count: \(cp.devices.count)) ==")
            for device in cp.devices.values {
                printDevice(device: device)
            }
        case "device":
            let udn = tokens[1]
            guard let device = cp.devices[udn] else {
                print("[ERR] No device found with UDN (\(udn))")
                continue
            }
            printDevice(device: device)
            session.device = device
        case "service":
            guard let device = session.device else {
                print("[ERR] Device is not selected")
                continue
            }
            let serviceType = tokens[1]
            guard let service = device.getService(type: serviceType) else {
                print("[ERR] No service found -- \(serviceType)")
                continue
            }
            session.service = service
            print("Selected Service (ID: \(service.serviceId ?? "nil"))")
            guard let scpd = service.scpd else {
                print("(No SCPD)")
                continue
            }
            print("  - Action List")
            for action in scpd.actions {
                print("    -- \(action.name ?? "nil")")
            }
        case "invoke", "i":
            guard tokens.count > 1 else {
                print("[ERR] Action name is required")
                continue
            }
            guard let service = session.service else {
                print("[ERR] Service is not selected")
                continue
            }

            handleInvokeAction(cp: cp, service: service, actionName: tokens[1])
        case "subscribe":
            guard let service = session.service else {
                print("[ERR] Service is not selected")
                continue
            }
            cp.subscribe(service: service) {
                (subscription) in
                print("[EVENT] Subscribe is done -- \(subscription.sid)")
            }
        default:
            print("[ERR] Unknown Command -- '\(tokens[0])'")
        }
    }

    cp.finish()
}


func printDevice(device: UPnPDevice) {
    print("[DEVICE] \(device.friendlyName ?? "nil") (UDN: \(device.udn ?? "nil"))")
    for service in device.services {
        print("  - [SERVICE] \(service.serviceType ?? "nil") (ID: \(service.serviceId ?? "nil"))")
        guard let scpd = service.scpd else {
            print("    -- (NO SCPD)")
            continue
        }
        
        if scpd.actions.isEmpty {
            print("    -- (NO ACTION)")
        } else {
            print("    -- Action Count: (\(scpd.actions.count))")
        }
        
        for action in scpd.actions {
            print("    -- \(action.name ?? "nil")")
        }
    }
}

func handleSearch(cp: UPnPControlPoint, st: String) {
    print("Searching... '\(st)'")
    cp.sendMsearch(st: st, mx: 3)
}

func handleInvokeAction(cp: UPnPControlPoint, service: UPnPService, actionName: String) {
    guard let scpd = service.scpd else {
        print("[ERR] Service has no scpd")
        return
    }
    guard let action = scpd.getAction(name: actionName) else {
        print("[ERR} No action name found with '\(actionName)'")
        return
    }
    let properties = OrderedProperties()
    for argument in action.arguments {
        guard let name = argument.name else {
            continue
        }
        guard argument.direction == .input else {
            continue
        }
        print(" -- IN Argument: \(name)")
        guard let argumentValue = readLine() else {
            print("[ERR] Failed to read argument value")
            return
        }
        properties[name] = argumentValue
    }
    let actionRequest = UPnPActionRequest(actionName: action.name!, fields: properties)
    cp.invoke(service: service, actionRequest: actionRequest) {
        (soapResponse) in
        guard let soapResponse = soapResponse else {
            print("[ERR] No soap response")
            return
        }
        print(" -== Action Response ==-")
        for field in soapResponse.fields {
            print("- \(field.key): \(field.value)")
        }
    }
}

main()
