import XCTest

import serverTests

var tests = [XCTestCaseEntry]()
tests += serverTests.allTests()
XCTMain(tests)
