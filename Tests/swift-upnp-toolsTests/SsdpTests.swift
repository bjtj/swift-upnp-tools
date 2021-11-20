//
// SsdpTests.swift
// 

import XCTest
@testable import SwiftUpnpTools
import SwiftHttpServer

/**
 DeviceTests
 */
final class SsdpTests: XCTestCase {

    func testSsdp() {
        XCTAssertEqual(SSDP.MCAST_HOST, "239.255.255.250")
        XCTAssertEqual(SSDP.MCAST_PORT, 1900)
    }

    func testSsdpHeader() {
        let header = SSDPHeader()
        let location = "http://example.com"
        header["Location"] = location
        XCTAssertEqual(header["Location"], location)
        XCTAssertEqual(header["LOCATION"], location)
        XCTAssertEqual(header["location"], location)
    }

    func testSsdpHeaderToString() {
        let header = SSDPHeader()
        let location = "http://example.com"
        header["Location"] = location
        XCTAssertEqual(header.description, "\r\nLocation: http://example.com\r\n\r\n")
    }

    func testSsdpHeaderFromString() {
        let text = "M-SEARCH * HTTP/1.1\r\n" +
          "HOST: \(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)\r\n" +
          "MAN: \"ssdp:discover\"\r\n" +
          "MX: 3\r\n" +
          "ST: ssdp:all\r\n" +
          "\r\n"
        let header = SSDPHeader.read(text: text)
        XCTAssertEqual(header.description, text)

        XCTAssertEqual(header.firstLineParts[0], "M-SEARCH")
        XCTAssertEqual(header.firstLineParts[1], "*")
        XCTAssertEqual(header.firstLineParts[2], "HTTP/1.1")

        XCTAssert(header.isMsearch)
    }

    func testSsdpReceiver() {
        print("send notify")
        let properties = OrderedProperties()
        properties["x"] = "x"
        SSDP.notify(properties: properties)
        print("send msearch")
        SSDP.sendMsearch(st: "ssdp:all", mx: 1)
    }
    
    static var allTests = [
      ("testSsdp", testSsdp),
      ("testSsdpHeader", testSsdpHeader),
      ("testSsdpHeaderToString", testSsdpHeaderToString),
      ("testSsdpHeaderFromString", testSsdpHeaderFromString),
      ("testSsdpReceiver", testSsdpReceiver),
    ]
}
