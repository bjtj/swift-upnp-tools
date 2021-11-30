//
// UPnPError.swift
//

/**
 UPnP Error
 */
public enum UPnPError: Error {
    case custom(string: String)
    case readFailed(string: String)
}
