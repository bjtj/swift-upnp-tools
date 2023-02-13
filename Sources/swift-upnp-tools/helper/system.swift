import Foundation

func osname() -> String {

    let versionString: String
    
    if #available(OSX 10.10, *) {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    } else {
        versionString = "10.9"
    }
    
    let osName: String = {
        #if os(iOS)
        return "iOS"
        #elseif os(watchOS)
        return "watchOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(OSX)
        return "OS X"
        #elseif os(macOS)
        return "MacOS"
        #elseif os(Linux)
        return "Linux"
        #else
        return "Unknown"
        #endif
    }()
    
    return "\(osName)/\(versionString)"

}
