import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
      testCase(SsdpTests.allTests),
      testCase(ModelTests.allTests),
      testCase(ServerTests.allTests),
    ]
}
#endif
