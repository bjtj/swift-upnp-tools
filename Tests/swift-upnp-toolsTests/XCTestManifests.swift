import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(swift_upnp_toolsTests.allTests),
    ]
}
#endif