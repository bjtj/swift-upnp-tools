import Foundation
import SwiftUpnpTools

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct Session {
    var device: UPnPDevice?
    var service: UPnPService?
}

func main() {

    print(" --=== UPnP ControlPoint ===--")

    var session = Session()

    var done = false

    let cp = UPnPControlPoint(httpServerBindPort: 0)
    do {
        try cp.run()
    } catch {
        exit(1)
    }


    cp.onDeviceAdded {
        (device) in
        print("-*- [ADDED] \(device.friendlyName ?? "nil") (UDN: \(device.udn ?? "nil"))")
    }

    cp.onDeviceRemoved {
        (device) in
        print("-*- [REMOVED] \(device.friendlyName ?? "nil") (UDN: \(device.udn ?? "nil"))")
    }

    cp.addNotificationHandler {
        (subscription, properties, error) in
        guard error == nil else {
            print("Error - \(error!)")
            return
        }
        guard let subscription = subscription, let properties = properties else {
            print("Error - no subscription or properties")
            return
        }
        guard let sid = subscription.sid else {
            print("Error - no sid")
            return
        }
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
            printSession(session: session)
            continue
        }
        switch tokens[0] {
        case "quit", "q":
            done = true
            break
        case "search":
            handleSearch(cp: cp, st: tokens[1])
        case "ls":
            print(" -== Device List (count: \(cp.presentableDevices.count)) ==-")
            for device in cp.presentableDevices.values {
                printDevice(device: device)
            }
        case "device":
            let udn = tokens[1]
            guard let device = cp.presentableDevices[udn] else {
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
            guard let device = session.device, let service = session.service else {
                print("[ERR] Device and Service must be selected")
                continue
            }
            guard let udn = device.udn else {
                print("[ERR] Device has no udn field <-- weird")
                continue
            }
            cp.subscribe(udn: udn, service: service) {
                (subscriber, error) in
                if let e = error {
                    print("[EVENT] Subscribe failed -- \(e)")
                }

                guard let subscriber = subscriber else {
                    print("[EVENT] Subscribe failed -- no subscriber")
                    return
                }

                guard let sid = subscriber.sid else {
                    print("[EVENT] Subscribe failed -- no sid")
                    return
                }
                
                print("[EVENT] Subscribe is done -- \(sid)")

            }
        default:
            print("[ERR] Unknown Command -- '\(tokens[0])'")
        }
    }

    cp.finish()

    print(" --=== DONE ===--")
}


func printDevice(device: UPnPDevice) {
    print("[DEVICE] \(device.friendlyName ?? "nil") (UDN: \(device.udn ?? "nil"))")
    for service in device.services {
        print("  - [SERVICE] \(service.serviceType ?? "nil") (ID: \(service.serviceId ?? "nil"))")
        if let error = service.error {
            print("    * STATUS: \(service.status) .. \(error)")
        } else {
            print("    * STATUS: \(service.status)")
        }
        
        guard let scpd = service.scpd else {
            print("    -- (NO SCPD)")
            continue
        }
        
        if scpd.actions.isEmpty {
            print("    -- (NO ACTION)")
        } else {
            print("    Action Count: (\(scpd.actions.count))")
        }
        
        for action in scpd.actions {
            print("    -- \(action.name ?? "nil")")
        }
    }
}

func printSession(session: Session) {
    print(" -== SESSION ==-")
    guard let device = session.device else {
        print("[DEVICE] not selected")
        return
    }
    print("[Device]  \(device.friendlyName ?? "nil") (UDN: \(device.udn ?? "nil"))")
    guard let service = session.service else {
        print("[ERR] Service is not selected")
        return
    }
    print("[Service] \(service.serviceType ?? "nil")")
}

/**
 handle search
 */
func handleSearch(cp: UPnPControlPoint, st: String) {
    print("Searching... '\(st)'")
    cp.sendMsearch(st: st, mx: 3)
}

/**
 handle invoke action
 */
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
        print(" -- [IN] read argument: '\(name)'")
        guard let argumentValue = readLine() else {
            print("[ERR] Failed to read argument value")
            return
        }
        properties[name] = argumentValue
    }
    
    let actionRequest = UPnPActionRequest(actionName: action.name!, fields: properties)

    cp.invoke(service: service, actionRequest: actionRequest) {
        (soapResponse, error) in

        guard error == nil else {
            print("Invoke Error - '\(error!)'")
            return
        }
        guard let soapResponse = soapResponse else {
            print("[ERR] No soap response")
            return
        }
        print(" -== Action Response ==-")
        for field in soapResponse.fields {
            print("  - \(field.key): \(field.value)")
        }
    }
}

main()
