import XCTest

#if !os(macOS) && !targetEnvironment(macCatalyst) && !os(iOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
      testCase(SsdpTests.allTests),
      testCase(ModelTests.allTests),
      testCase(ServerTests.allTests),
    ]
}
#endif
