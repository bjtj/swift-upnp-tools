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
        print("Device added -- \(device.udn ?? "nil") / \(device.friendlyName ?? "nil")")
    }

    cp.onDeviceRemoved {
        (device) in
        print("Device removed -- \(device.udn ?? "nil") / \(device.friendlyName ?? "nil")")
    }

    cp.onEventProperty {
        (sid, properties) in
        print("Event notify -- sid: \(sid)")
        for field in properties.fields {
            print("- \(field.key): \(field.value)")
        }
    }

    while done == false {
        guard let line = readLine() else {
            continue
        }
        let tokens = line.split(separator: " ", maxSplits: 1).map { String($0) }
        guard tokens.isEmpty == false else {
            print(" == session ==")
            guard let device = session.device else {
                print("Device is not selected")
                continue
            }
            print("device -- \(device.udn ?? "nil") \(device.friendlyName ?? "nil")")
            for service in device.services {
                print(" - \(service.serviceType ?? "nil")")
            }
            guard let service = session.service else {
                print("Service is not selected")
                continue
            }
            print("service -- \(service.serviceType ?? "nil")")
            continue
        }
        switch tokens[0] {
        case "quit", "q":
            done = true
            break
        case "search":
            cp.sendMsearch(st: tokens[1], mx: 3)
        case "ls":
            print(" == devices (count: \(cp.devices.count)) ==")
            for device in cp.devices.values {
                print("* \(device.udn ?? "nil") -- \(device.friendlyName ?? "nil")")
            }
        case "device":
            let udn = tokens[1]
            guard let device = cp.devices[udn] else {
                print("No device with UDN (\(udn))")
                continue
            }
            print("Selected: \(device.udn ?? "nil") \(device.friendlyName ?? "nil")")
            for service in device.services {
                print(" - service: \(service.serviceType ?? "nil")")
            }
            session.device = device
        case "service":
            guard let device = session.device else {
                print("Device is not selected")
                continue
            }
            let serviceType = tokens[1]
            guard let service = device.getService(type: serviceType) else {
                print("No service found -- \(serviceType)")
                continue
            }
            session.service = service
            print("selected service id -- \(service.serviceId ?? "nil")")
            guard let scpd = service.scpd else {
                print("No scpd")
                continue
            }
            for action in scpd.actions {
                print("- action: \(action.name ?? "nil")")
            }
        case "invoke":
            guard tokens.count > 1 else {
                print("Action name is required")
                continue
            }
            guard let service = session.service else {
                print("Service is not selected")
                continue
            }
            guard let scpd = service.scpd else {
                print("Service has no scpd")
                continue
            }
            guard let action = scpd.getAction(name: tokens[1]) else {
                print("No action name -- \(tokens[1])")
                continue
            }
            let properties = OrderedProperties()
            for argument in action.arguments {
                guard let name = argument.name else {
                    continue
                }
                guard argument.direction == .input else {
                    continue
                }
                print("- in argument: \(name)")
                guard let argumentValue = readLine() else {
                    print("Failed to read argument value")
                    return
                }
                properties[name] = argumentValue
            }
            let actionRequest = UPnPActionRequest(actionName: action.name!, fields: properties)
            cp.invoke(service: service, actionRequest: actionRequest) {
                (soapResponse) in
                guard let soapResponse = soapResponse else {
                    print("No soap response")
                    return
                }
                print("Action response")
                for field in soapResponse.fields {
                    print("- \(field.key): \(field.value)")
                }
            }
        case "subscribe":
            guard let service = session.service else {
                print("Service is not selected")
                continue
            }
            cp.subscribe(service: service) {
                (subscription) in
                print("Subscribe is done -- \(subscription.sid)")
            }
        default:
            print("Unknown command -- \(tokens[0])")
        }
    }

    cp.finish()
}

main()
