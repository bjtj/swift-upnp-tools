

public enum UPnPActionError: Error {
    case custom(Int, String)
    case invalidAction
    case invalidArgs
    case actionFailed
    case argumentValueInvalid
    case argumentValueOutOfRange
    case optionalActionNotImplemented
    case outOfMemory
    case humanInterventionRequired
    case stringArgumentTooLong

    struct Code: Equatable {
        let code: Int
        let description: String

        static func == (l: Code, r: Code) -> Bool {
            return l.code == r.code && l.description == r.description
        }

        static var invalidAction: UPnPActionError.Code {
            return Code(code: 401, description: "Invalid Action")
        }
        static var invalidArgs: UPnPActionError.Code {
            return Code(code: 402, description: "Invalid Args")
        }
        static var actionFailed: UPnPActionError.Code {
            return Code(code: 501, description: "Action Failed")
        }
        static var argumentValueInvalid: UPnPActionError.Code {
            return Code(code: 600, description: "Argument Value Invalid")
        }
        static var argumentValueOutOfRange: UPnPActionError.Code {
            return Code(code: 601, description: "Argument Value Out of Range")
        }
        static var optionalActionNotImplemented: UPnPActionError.Code {
            return Code(code: 602, description: "Optional Action Not Implemented")
        }
        static var outOfMemory: UPnPActionError.Code {
            return Code(code: 603, description: "Out of Memory")
        }
        static var humanInterventionRequired: UPnPActionError.Code {
            return Code(code: 604, description: "Human Intervention Required")
        }
        static var stringArgumentTooLong: UPnPActionError.Code {
            return Code(code: 605, description: "String Argument Too Long")
        }
    }

    typealias RawValue = Code

    var rawValue: RawValue {
        switch self {
        case .custom(let code, let description):
            return Code(code: code, description: description)
        case .invalidAction: return Code.invalidAction
        case .invalidArgs: return Code.invalidArgs
        case .actionFailed: return Code.actionFailed
        case .argumentValueInvalid: return Code.argumentValueInvalid
        case .argumentValueOutOfRange: return Code.argumentValueOutOfRange
        case .optionalActionNotImplemented: return Code.optionalActionNotImplemented
        case .outOfMemory: return Code.outOfMemory
        case .humanInterventionRequired: return Code.humanInterventionRequired
        case .stringArgumentTooLong: return Code.stringArgumentTooLong
        }
    }

    init?(code: Int, description: String) {
        self = .custom(code, description)
    }

    init?(rawValue: Int) {
        switch rawValue {
        case 401: self = .invalidAction
        case 402: self = .invalidArgs
        case 501: self = .actionFailed
        case 600: self = .argumentValueInvalid
        case 601: self = .argumentValueOutOfRange
        case 602: self = .optionalActionNotImplemented
        case 603: self = .outOfMemory
        case 604: self = .humanInterventionRequired
        case 605: self = .stringArgumentTooLong
        default:
            return nil
        }
    }

    var description: String {
        return "\(rawValue.code) \(rawValue.description)"
    }
}
