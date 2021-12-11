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
        XCTAssertEqual(location, header.location)
        XCTAssertEqual(location, header["LOCATION"])
        header["Location"] = nil
        XCTAssertNil(header.location)
    }

    func testSsdpHeaderFromString() {
        do {
            let text = "M-SEARCH * HTTP/1.1\r\n" +
              "HOST: \(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)\r\n" +
              "MAN: \"ssdp:discover\"\r\n" +
              "MX: 3\r\n" +
              "ST: ssdp:all\r\n" +
              "\r\n"
            guard let header = SSDPHeader.read(text: text) else {
                XCTFail("SSDPHeader.read() failed")
                return
            }
            XCTAssertEqual(header.description, text)

            XCTAssertEqual(header.firstLineParts[0], "M-SEARCH")
            XCTAssertEqual(header.firstLineParts[1], "*")
            XCTAssertEqual(header.firstLineParts[2], "HTTP/1.1")

            XCTAssertTrue(header.isMsearch)
        }

        do {
            let text = "M-SEARCH  * \t HTTP/1.1\r\n" +
              "HOST: \(SSDP.MCAST_HOST):\(SSDP.MCAST_PORT)\r\n" +
              "MAN: \"ssdp:discover\"\r\n" +
              "MX: 3\r\n" +
              "ST: ssdp:all\r\n" +
              "\r\n"
            guard let header = SSDPHeader.read(text: text) else {
                XCTFail("SSDPHeader.read() failed")
                return
            }
            // XCTAssertEqual(header.description, text)

            XCTAssertEqual(header.firstLineParts[0], "M-SEARCH")
            XCTAssertEqual(header.firstLineParts[1], "*")
            XCTAssertEqual(header.firstLineParts[2], "HTTP/1.1")

            XCTAssertTrue(header.isMsearch)
        }
    }

    func testSsdpReceiver() {
        let properties = OrderedProperties()
        properties["x"] = "x"
        SSDP.notify(properties: properties)
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
