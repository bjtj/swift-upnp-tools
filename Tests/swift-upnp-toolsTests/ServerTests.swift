//
// ServerTests.swift
// 

import XCTest
@testable import SwiftUpnpTools
import SwiftHttpServer

/**
 ServerTests
 */
final class ServerTests: XCTestCase {

    /**
     UPnP Sever for test
     */
    static var upnpServer: UPnPServer?
    static var receiver: SSDPReceiver?

    var controlpointMonitoringHandler: UPnPControlPoint.monitoringHandler? = {
        (cp, name, component, status) in
        print(" ****** [\(name ?? "")] component: \(component) -- status: \(status)")
        if component == .httpserver && status == .started {
            print("Http Server is bound to \(cp.httpServer?.serverAddress?.description ?? "")")
        }
    }

    static var serverMonitoringHandler: UPnPServer.monitoringHandler? = {
        (server, name, component, status) in
        print(" ****** [\(name ?? "")] component: \(component) -- status: \(status)")
        if component == .httpserver && status == .started {
            print("Http Server is bound to \(server.httpServer?.serverAddress?.description ?? "")")
        }
    }

    /**
     set up
     */
    override class func setUp() {
        super.setUp()

        print("-- SET UP --")

        DispatchQueue.global(qos: .background).async {
            startReceiver()
        }

        do {
            upnpServer = try startServer()
        } catch {
            XCTFail("startServer()")
        }
        
        sleep(1)

        print("-- SET UP :: DONE --")
    }

    /**
     start server
     */
    class func startServer() throws -> UPnPServer {
        let server = UPnPServer(httpServerBindPort: 0)
        server.monitor(name: "server-monitor", handler: serverMonitoringHandler)
        try server.run()

        try registerDevice(server: server)
        
        return server
    }

    /**
     register device
     */
    class func registerDevice(server: UPnPServer) throws {
        guard let device = try UPnPDevice.read(xmlString: ServerTests.deviceDescription_DimmableLight) else {
            XCTFail("UPnPDevice read failed")
            return
        }

        guard let service = device.getService(type: "urn:schemas-upnp-org:service:SwitchPower:1") else {
            XCTFail("No Service (urn:schemas-upnp-org:service:SwitchPower:1)")
            return
        }
        service.scpd = try UPnPScpd.read(xmlString: ServerTests.scpd_SwitchPower)

        XCTAssertNotNil(service.scpd)
        
        server.registerDevice(device: device)
        server.activate(device: device)
    }

    /**
     teardown
     */
    override class func tearDown() {
        print("-- TEAR DOWN --")
        super.tearDown()
        ServerTests.upnpServer?.finish()
        receiver?.finish()
        print("-- TEAR DOWN :: DONE --")
        sleep(1)
    }

    /**
     start receiver
     */
    class func startReceiver() {
        do {
            receiver = try SSDPReceiver() {
                (address, ssdpHeader, error) in
                if let ssdpHeader = ssdpHeader {
                    if let address = address {
                        let date = Date()
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm:ss.SSS"
                        print("[\(formatter.string(from: date))] SSDP from -- \(address.hostname):\(address.port)")
                        print("\t- \(ssdpHeader.nts?.rawValue ?? "(NO NTS)") \(ssdpHeader.nt ?? "(NO NT)")")
                        if ssdpHeader.nts == .alive || ssdpHeader.nts == .update {
                            print("\t- LOCATION: \(ssdpHeader.location ?? "(NO LOCATION)")")
                        }
                    }
                }
                return nil
            }
            try receiver?.run()
        } catch let error {
            print(error)
        }
        print("-- Receiver Done --")
    }

    /**
     test notify
     */
    func testNotify() throws {

        // guard let receiver = ServerTests.receiver else {
        //     XCTFail("no ssdp receiver")
        //     return
        // }

        // let listener = receiver.listener(
        //   add: {
        //       (address, ssdpHeader, error) in
        //       guard let header = ssdpHeader else {
        //           return
        //       }
        //       print("[SSDP LISTENER] \(header.description)")
        //   })

        // defer {
        //     print("== REMOVE LISTENER ==")
        //     listener.remove()
        // }
        
        guard let device = try UPnPDevice.read(xmlString: ServerTests.deviceDescription_DimmableLight) else {
            XCTFail("cannot read device")
            return
        }
        guard let addr = Network.getInetAddress() else {
            XCTFail("no get inet address result");
            return
        }
        UPnPServer.announceDeviceAlive(device: device, location: "http://\(addr.hostname)/fakeurl")
        UPnPServer.announceDeviceByeBye(device: device)

        sleep(1)

        UPnPServer.META_APP_NAME = "UPnPServerTest/1.0"

        UPnPServer.announceDeviceAlive(device: device, location: "http://\(addr.hostname)/fakeurl")
        UPnPServer.announceDeviceByeBye(device: device)

        sleep(1)

        let server = UPnPServer(httpServerBindPort: 0)
        try server.run()

        sleep(1)

        print("========== TEST NOTIFY : ALIVE ==========")

        server.activate(device: device)

        sleep(1)

        print("========== TEST NOTIFY : BYEBYE ==========")

        server.deactivate(device: device)

        sleep(1)

        print("========== TEST NOTIFY : DONE ==========")
    }

    /**
     test server
     */
    func testServer() {

        guard let server = ServerTests.upnpServer else {
            XCTFail("UPnPServer is not ready")
            return
        }

        let udn = "uuid:e399855c-7ecb-1fff-8000-000000000000"
        let device = server.getDevice(udn: udn)
        XCTAssertNotNil(device)

        server.on(
          eventSubscription: {
              subscription in
              print("event subscription - \(subscription.udn) \(subscription.callbackUrls)")
          })

        // -------------------------------------------

        server.on(
          actionRequest: {
              (service, soapRequest) in

              if soapRequest.actionName == "GetLoadLevelTarget" {
                  let properties = OrderedProperties()
                  properties["GetLoadlevelTarget"] = "10"
                  return properties
              }

              if soapRequest.actionName == "ExepctError" {
                  throw UPnPActionError.custom(401, "custom invalid action")
              }

              throw UPnPActionError.invalidAction
              
          })

        var called = false

        let actionRequest = UPnPActionRequest(actionName: "GetLoadLevelTarget")
        helperControlPointInvokeAction(st: "ssdp:all",
                                       serviceType: "urn:schemas-upnp-org:service:SwitchPower:1",
                                       expectedUdn: udn,
                                       actionRequest: actionRequest)
        {
            (soapResponse, error) in

            called = true
            
            XCTAssertNil(error)
            if let soapResponse = soapResponse {
                print("[ACTION INVOKE] soapResponse:\n\(soapResponse.description)")
            }
            XCTAssertEqual(soapResponse?["GetLoadlevelTarget"], "10")
        }

        helperControlPointInvokeAction(st: "ssdp:all",
                                       serviceType: "urn:schemas-upnp-org:service:SwitchPower:1",
                                       expectedUdn: udn,
                                       actionRequest: UPnPActionRequest(actionName: "mustfail"))
        {
            (soapResponse, error) in

            if let error = error {
                print("action name: mustfail - invoke action error \(error)")
                return
            }

            if let response = soapResponse {
                print("action name: mustfail - response \(response.description)")
            }
        }

        helperControlPointInvokeAction(st: "ssdp:all",
                                       serviceType: "urn:schemas-upnp-org:service:SwitchPower:1",
                                       expectedUdn: udn,
                                       actionRequest: UPnPActionRequest(actionName: "ExepctError"))
        {
            (soapResponse, error) in

            if let error = error {
                print("action name: ExpectError - invoke action error \(error)")
                return
            }

            if let response = soapResponse {
                print("action name: ExpectError - response \(response.description)")
            }
        }
        

        // -------------------------------------------

        let service = device!.getService(type: "urn:schemas-upnp-org:service:SwitchPower:1")
        XCTAssertNotNil(service)
        XCTAssertNotNil(device!.udn)
        helperEventSubscribe(st: "ssdp:all", serviceType: "urn:schemas-upnp-org:service:SwitchPower:1", server: server, udn: device!.udn!, service: service!, properties: ["GetLoadlevelTarget" : "12"])

        helperEventSubscribeAndRenewal(st: "ssdp:all", serviceType: "urn:schemas-upnp-org:service:SwitchPower:1", server: server, udn: device!.udn!)
        
        helperEventSubscribeAndUnsubscribe(st: "ssdp:all", serviceType: "urn:schemas-upnp-org:service:SwitchPower:1", server: server, udn: device!.udn!, service: service!, properties: ["GetLoadlevelTarget" : "321"])
        

        sleep(1)


        // -------------------------------------------

        XCTAssertTrue(called)
    }

    /**
     helper control point invoke action
     */
    func helperControlPointInvokeAction(st: String,
                                        serviceType: String,
                                        expectedUdn udn: String,
                                        actionRequest: UPnPActionRequest,
                                        handler: (UPnPActionInvoke.invokeCompletionHandler)?)
    {
        let cp = UPnPControlPoint()
        cp.monitor(name: "cp-monitor", handler: controlpointMonitoringHandler)

        var handledService = [UPnPService]()

        cp.on(
          scpd: {
              (device, service, scpd, error) in
              
              guard let x = device?.udn, x == udn, let y = service?.serviceType, y == serviceType else {
                  //                not expected udn
                  return
              }

              guard error == nil else {
                  // error
                  XCTFail("error - \(error!)")
                  return
              }

              guard let service = service else {
                  // error
                  return
              }

              guard service.serviceType == serviceType else {
                  // not expected service
                  return
              }

              cp.invoke(service: service, actionRequest: actionRequest, completionHandler: handler)

              handledService.append(service)
          })

        do {
            try cp.run()
            sleep(2)
        } catch let e {
            XCTFail("cp.run() failed \(e)")
            return
        }

        guard let httpServer = cp.httpServer else {
            XCTFail("cp.httpServer is nil")
            return
        }
        XCTAssertTrue(httpServer.running)

        guard let ssdpReceiver = cp.ssdpReceiver else {
            XCTFail("cp.ssdpReceiver is nil")
            return
        }
        XCTAssertTrue(ssdpReceiver.running)

        cp.sendMsearch(st: st, mx: 3,
                       ssdpHandler: {
                           (address, header, error) in
                           guard let _ = header else {
                               return nil
                           }
                           return nil
                       })

        sleep(3)

        XCTAssertFalse(handledService.isEmpty)

        cp.finish()

        usleep(500 * 1000)
        XCTAssertFalse(cp.running)
    }


    /**
     event subscribe
     */
    func helperEventSubscribe(st: String, serviceType: String, server: UPnPServer, udn: String, service: UPnPService, properties: [String:String]) -> Void {
        let cp = UPnPControlPoint()
        cp.monitor(name: "cp-monitor", handler: controlpointMonitoringHandler)

        var handledService: [UPnPService] = []
        var handledEvents: [UPnPEventSubscriber] = []
        var serviceId: String? = nil

        cp.on(scpd: {
                  (device, service, scpd, error) in
                  
                  guard let x = device?.udn, x == udn, let y = service?.serviceType, y == serviceType else {
                      //                not expected device
                      return
                  }

                  guard error == nil else {
                      // error
                      XCTFail("error - \(error!)")
                      return
                  }

                  guard let service = service else {
                      // error
                      return
                  }

                  guard service.serviceType == serviceType else {
                      // not expected service
                      return
                  }

                  serviceId = service.serviceId

                  guard let device = device, let udn = device.udn else {
                      // error
                      return
                  }

                  do {
                      try cp.subscribe(udn: udn,
                                       service: service,
                                       completionHandler: {
                                           (subscriber, error) in
                                           XCTAssertNil(error)
                                           guard let subscriber = subscriber else {
                                               XCTFail("No Subscriber")
                                               return
                                           }
                                           XCTAssertNotNil(subscriber.sid)
                                           print("[SUBSCRIBE] result (SID: '\(subscriber.sid!)')")
                                           
                                       })?.onNotification {
                          (subscriber, properties, error) in
                          guard error == nil else {
                              XCTFail("notification error - \(error!)")
                              return
                          }
                          guard let subscriber = subscriber else {
                              XCTFail("no subscriber")
                              return
                          }
                          guard let sid = subscriber.sid else {
                              XCTFail("no sid")
                              return
                          }
                          XCTAssertNotNil(properties)
                          print("ON EVENT -- SID: \(sid), SEQ: \(subscriber.seq)\n- \(properties?.description ?? "nil")")

                          handledEvents.append(subscriber)
                      }

                  } catch {
                      XCTFail("failed - \(error)")
                      return
                  }

                  handledService.append(service)
              })

        cp.on(eventProperties: {
                  (subscriber, props, error) in
                  print("[EXTRA EVENT LOG] EVENT COME~ '\(props?.description ?? "nil")'")

                  guard let subscriber = subscriber else {
                      XCTFail("no subscriber")
                      return
                  }

                  print("ON EVENT - SID: \(subscriber.sid ?? "(no sid)") , SEQ: \(subscriber.seq)")
                  
                  handledEvents.append(subscriber)
              })

        cp.on(eventProperties: {
                  (subscriber, props, error) in

                  guard error == nil else {
                      print("[EVENT] Notification Handling Error - \(error!)")
                      return
                  }

                  guard let subscriber = subscriber else {
                      XCTFail("no subscriber")
                      return
                  }

                  print("ON EVENT - SID: \(subscriber.sid ?? "(no sid)") , SEQ: \(subscriber.seq)")

                  guard let props = props else {
                      XCTFail("no properties")
                      return
                  }

                  XCTAssertEqual(properties.count, props.fields.count)

                  XCTAssertNotNil(subscriber.sid)
                  print("x [EVENT] Notification (SID: '\(subscriber.sid!)')")
                  for field in props.fields {
                      print("- Property - '\(field.key)': '\(field.value)'")
                      XCTAssertNotNil(properties[field.key])
                      XCTAssertEqual(properties[field.key]!, field.value)
                  }

                  handledEvents.append(subscriber)
              })

        do {
            try cp.run()
            sleep(2)
        } catch let e {
            XCTFail("cp.run() failed \(e)")
            return
        }

        cp.sendMsearch(st: st, mx: 3)

        sleep(3)

        XCTAssertNotNil(service.serviceId)

        let repeatCount = 3

        for _ in (0..<repeatCount) {
            server.setProperty(udn: udn, serviceId: service.serviceId!, properties: properties) {
                subscription, error in
                if let error = error {
                    XCTFail("set property error - \(error)")
                    return
                }
            }
        }

        sleep(1)

        XCTAssertNotNil(serviceId)
        if let serviceId = serviceId {
            XCTAssertFalse(cp.getEventSubscribers(forServiceId: serviceId).isEmpty)
        }
        XCTAssertFalse(handledService.isEmpty)
        XCTAssertFalse(handledEvents.isEmpty)
        XCTAssertEqual(handledEvents.count, 3 * repeatCount)

        cp.finish()

        usleep(500 * 1000)
        XCTAssertFalse(cp.running)
    }


    /**
     event subscribe and renewal
     */
    func helperEventSubscribeAndRenewal(st: String, serviceType: String, server: UPnPServer, udn: String) -> Void {
        let cp = UPnPControlPoint()
        cp.monitor(name: "cp-monitor", handler: controlpointMonitoringHandler)

        var handledService = [UPnPService]()
        var handledEvents = [UPnPEventSubscriber]()

        var serviceId: String? = nil

        cp.on(scpd: {
                  (device, service, scpd, error) in
                  
                  guard let x = device?.udn, x == udn, let y = service?.serviceType, y == serviceType else {
                      //                not expected device
                      return
                  }

                  guard error == nil else {
                      // error
                      XCTFail("error - \(error!)")
                      return
                  }

                  guard let service = service else {
                      // error
                      return
                  }

                  guard service.serviceType == serviceType else {
                      // not expected service
                      return
                  }

                  serviceId = service.serviceId

                  guard let device = device, let udn = device.udn else {
                      // error
                      return
                  }

                  do {
                      try cp.subscribe(
                        udn: udn,
                        service: service,
                        completionHandler: {
                            (subscriber, error) in
                            XCTAssertNil(error)
                            guard let subscriber = subscriber else {
                                XCTFail("No Subscriber")
                                return
                            }
                            XCTAssertNotNil(subscriber.sid)
                            print("[SUBSCRIBE] ok (SID: '\(subscriber.sid!)', tick: \(subscriber.tick))")

                            DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + 1) {
                                subscriber.renewSubscribe {
                                    (subscriber, error) in

                                    if let err = error {
                                        XCTFail("renew error - \(err)")
                                        return
                                    }

                                    guard let subscriber = subscriber else {
                                        XCTFail("no subscriber")
                                        return
                                    }

                                    print("[SUBSCRIBE] renew ok (SID: '\(subscriber.sid!)', tick: \(subscriber.tick))")

                                    handledEvents.append(subscriber)
                                }
                            }
                            
                        })

                  } catch {
                      XCTFail("failed - \(error)")
                      return
                  }

                  handledService.append(service)
              })

        do {
            try cp.run()
            sleep(2)
        } catch let e {
            XCTFail("cp.run() failed \(e)")
            return
        }

        cp.sendMsearch(st: st, mx: 3)

        sleep(5)

        XCTAssertNotNil(serviceId)
        if let serviceId = serviceId {
            XCTAssertFalse(cp.getEventSubscribers(forServiceId: serviceId).isEmpty)
        }
        XCTAssertFalse(handledService.isEmpty)
        XCTAssertFalse(handledEvents.isEmpty)
        XCTAssertEqual(handledEvents.count, 1)

        cp.finish()

        usleep(500 * 1000)
        XCTAssertFalse(cp.running)
    }

    /**
     event subscribe and unsubscribe
     */
    func helperEventSubscribeAndUnsubscribe(st: String, serviceType: String, server: UPnPServer, udn: String, service: UPnPService, properties: [String:String]) -> Void {
        let cp = UPnPControlPoint()
        cp.monitor(name: "cp-monitor", handler: controlpointMonitoringHandler)

        var handledService = [UPnPService]()
        var handledEvents = [UPnPEventSubscriber?]()
        var unsubscribeCalled = false
        var serviceId: String? = nil

        cp.on(scpd: {
                  (device, service, scpd, error) in
                  
                  guard let x = device?.udn, x == udn, let y = service?.serviceType, y == serviceType else {
                      //                not expected device
                      return
                  }

                  guard error == nil else {
                      // error
                      XCTFail("error - \(error!)")
                      return
                  }

                  guard let service = service else {
                      // error
                      return
                  }

                  guard service.serviceType == serviceType else {
                      // not expected service
                      return
                  }

                  serviceId = service.serviceId

                  guard let device = device, let udn = device.udn else {
                      // error
                      return
                  }

                  do {
                      try cp.subscribe(
                        udn: udn,
                        service: service,
                        completionHandler: {
                            (subscriber, error) in
                            XCTAssertNil(error)
                            guard let sub = subscriber else {
                                XCTFail("No Subscriber")
                                return
                            }
                            XCTAssertNotNil(sub.sid)
                            print("[SUBSCRIBE] result (SID: '\(sub.sid!)')")

                            DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + 0.1) {

                                XCTAssertNotNil(serviceId)
                                if let serviceId = serviceId {
                                    XCTAssertFalse(cp.getEventSubscribers(forServiceId: serviceId).isEmpty)
                                }

                                XCTAssertNotNil(sub.sid)
                                cp.unsubscribe(sid: sub.sid!) {
                                    (subscriber, error) in
                                    guard error == nil else {
                                        XCTFail("unsubscribe - error: \(error!)")
                                        return
                                    }
                                    guard let sid = subscriber?.sid else {
                                        XCTFail("unsubscribe - no sid")
                                        return
                                    }
                                    print("\(Date()) - unsubscribed")
                                    XCTAssertEqual(sid, sub.sid)
                                    unsubscribeCalled = true
                                }
                            }
                        })

                  } catch {
                      XCTFail("failed - \(error)")
                      return
                  }

                  handledService.append(service)
              })

        cp.on(eventProperties: {
                  (subscriber, props, error) in

                  if let subscriber = subscriber {
                      print("ON EVENT - SID: \(subscriber.sid ?? "(no sid)") , SEQ: \(subscriber.seq)")
                  }
                  
                  handledEvents.append(subscriber)
              })

        do {
            try cp.run()
            sleep(2)
        } catch let e {
            XCTFail("cp.run() failed \(e)")
            return
        }

        cp.sendMsearch(st: st, mx: 3)

        sleep(3)

        XCTAssertNotNil(service.serviceId)
        server.setProperty(udn: udn, serviceId: service.serviceId!, properties: properties) {
            subscription, error in
            if let error = error {
                XCTFail("set property error - \(error)")
                return
            }
        }

        sleep(3)

        XCTAssertNotNil(serviceId)
        if let serviceId = serviceId {
            XCTAssertTrue(cp.getEventSubscribers(forServiceId: serviceId).isEmpty)
        }

        XCTAssertFalse(handledService.isEmpty)
        XCTAssertTrue(handledEvents.isEmpty)
        XCTAssertTrue(unsubscribeCalled)

        cp.finish()

        usleep(500 * 1000)
        XCTAssertFalse(cp.running)
    }

    /**
     test control point
     */
    func testControlPoint() {

        guard let server = ServerTests.upnpServer else {
            XCTFail("UPnPServer is not ready")
            return
        }

        let udn = "uuid:e399855c-7ecb-1fff-8000-000000000000"
        guard let device = server.getDevice(udn: udn) else {
            XCTFail("server.getDevice failed")
            return
        }

        let service = device.services[0]
        
        server.on(
          actionRequest: {
              (service, soapRequest) in
              let properties = OrderedProperties()
              properties["GetLoadlevelTarget"] = "10"
              return properties
          })

        helperControlPointDiscovery(st: "ssdp:all", expectedUdn: udn, serviceType: "urn:schemas-upnp-org:service:SwitchPower:1")
        helperControlPointDiscovery(st: "upnp:rootdevice", expectedUdn: udn, serviceType: "urn:schemas-upnp-org:service:SwitchPower:1")

        helperControlPointSuspendResume(st: "ssdp:all", serviceType: "urn:schemas-upnp-org:service:SwitchPower:1", server: server, udn: udn, service: service, properties: ["GetLoadlevelTarget" : "14"])
        
        helperControlPointSuspendResumeTimeout(st: "ssdp:all", serviceType: "urn:schemas-upnp-org:service:SwitchPower:1", server: server, udn: udn, service: service, properties: ["GetLoadlevelTarget" : "2"])
    }

    
    /**
     helper control point discovery
     */
    func helperControlPointDiscovery(st: String, expectedUdn udn: String, serviceType: String) {
        let cp = UPnPControlPoint()
        cp.monitor(name: "cp-monitor", handler: controlpointMonitoringHandler)

        var handledDevices = [UPnPDevice]()
        var handledScpds = [UPnPScpd]()

        cp.on(
          addDevice: {
              (device) in
              
              guard let x = device.udn, x == udn else {
                  //                unexpected device
                  return
              }
              
              print(">>>>>>>>>>>>>> DEVICE ADDED -- \(device.udn ?? "nil") \(device.deviceType ?? "nil")")

              guard let _ = device.getService(type: serviceType) else {
                  // no expected service found
                  return
              }
              handledDevices.append(device)
          })

        cp.on(scpd: {
                  (device, service, scpd, error) in
                  
                  guard let x = device?.udn, x == udn, let y = service?.serviceType, y == serviceType else {
                      //                unexpected device
                      return
                  }

                  if let error = error {
                      print("ERROR - \(error)")
                      XCTAssertEqual(service?.status, .failed)
                      return
                  }

                  guard let service = service else {
                      XCTFail("service is nil")
                      return
                  }

                  guard let scpd = scpd else {
                      XCTFail("scpd is nil")
                      return
                  }
                  
                  XCTAssertNotNil(service.scpd)
                  XCTAssertEqual(service.status, .completed)

                  guard let action = scpd.getAction(name: "SetLoadLevelTarget") else {
                      XCTFail("get action failed - \"SetLoadLevelTarget\"")
                      return
                  }
                  XCTAssertNotNil(action.arguments)
                  XCTAssertNotNil(action.arguments[0])
                  XCTAssertEqual("newLoadlevelTarget", scpd.getAction(name: "SetLoadLevelTarget")!.arguments[0].name)
                  
                  handledScpds.append(scpd)
              })

        do {
            try cp.run()
            sleep(2)
        } catch let e {
            XCTFail("cp.run() failed \(e)")
            return
        }

        cp.sendMsearch(st: st, mx: 3)

        sleep(3)

        XCTAssertFalse(handledDevices.isEmpty)
        XCTAssertFalse(handledScpds.isEmpty)

        cp.finish()

        usleep(500 * 1000)
        XCTAssertFalse(cp.running)
    }

    /**
     suspend resume
     */
    func helperControlPointSuspendResume(st: String, serviceType: String, server: UPnPServer, udn: String, service: UPnPService, properties: [String:String]) -> Void {
        let cp = UPnPControlPoint()
        cp.monitor(name: "cp-monitor", handler: controlpointMonitoringHandler)

        var handledService = [UPnPService]()
        var handledEvents = [UPnPEventSubscriber]()

        var serviceId: String? = nil

        cp.on(scpd: {
                  (device, service, scpd, error) in
                  
                  guard let x = device?.udn, x == udn, service?.serviceType == serviceType else {
                      //                unexpected device
                      return
                  }

                  guard error == nil else {
                      // error
                      XCTFail("error - \(error!)")
                      return
                  }

                  guard let service = service else {
                      // error
                      return
                  }

                  guard service.serviceType == serviceType else {
                      // not expected service
                      return
                  }

                  serviceId = service.serviceId

                  guard let device = device, let udn = device.udn else {
                      // error
                      return
                  }

                  if cp.getEventSubscribers(forUdn: udn).isEmpty {
                      do {
                          try cp.subscribe(
                            udn: udn,
                            service: service,
                            completionHandler: {
                                (subscriber, error) in
                                XCTAssertNil(error)
                                guard let subscriber = subscriber else {
                                    XCTFail("No Subscriber")
                                    return
                                }
                                XCTAssertNotNil(subscriber.sid)
                                print("[SUBSCRIBE] result (SID: '\(subscriber.sid!)')")

                                subscriber.onNotification {
                                    (subscriber, properties, error) in
                                    guard let subscriber = subscriber else {
                                        XCTFail("subscriber is nil")
                                        return
                                    }
                                    print("SID - '\(subscriber.sid ?? "nil")'\n\(properties?.description ?? "nil")")
                                    handledEvents.append(subscriber)
                                }
                            })
                      } catch {
                          XCTFail("failed - \(error)")
                          return
                      }
                  }

                  handledService.append(service)
              })

        cp.on(eventProperties: {
                  (subscriber, props, error) in

                  guard error == nil else {
                      print("[EVENT] Notification Handling Error - \(error!)")
                      return
                  }
                  
                  guard let subscriber = subscriber else {
                      XCTFail("subscriber is nil")
                      return
                  }

                  print("ON EVENT - SID: \(subscriber.sid ?? "(no sid)") , SEQ: \(subscriber.seq)")

                  XCTAssertNotNil(properties)
                  guard let props = props else {
                      return
                  }

                  XCTAssertEqual(properties.count, props.fields.count)

                  XCTAssertNotNil(subscriber.sid)
                  print("x [EVENT] Notification (SID: '\(subscriber.sid!)')")
                  for field in props.fields {
                      print("- Property - '\(field.key)': '\(field.value)'")
                      XCTAssertNotNil(properties[field.key])
                      XCTAssertEqual(properties[field.key]!, field.value)
                  }

                  handledEvents.append(subscriber)
              })

        do {
            try cp.run()
            sleep(2)
        } catch let e {
            XCTFail("cp.run() failed \(e)")
            return
        }

        cp.sendMsearch(st: st, mx: 3)

        sleep(3)

        XCTAssertNotNil(service.serviceId)
        server.setProperty(udn: udn, serviceId: service.serviceId!, properties: properties) {
            subscription, error in
            if let error = error {
                XCTFail("set property error - \(error)")
                return
            }
        }

        sleep(1)

        XCTAssertNotNil(serviceId)
        if let serviceId = serviceId {
            XCTAssertFalse(cp.getEventSubscribers(forServiceId: serviceId).isEmpty)
        }


        // ----------------------

        cp.suspend()

        sleep(1)

        do {
            try cp.resume()
        } catch let err {
            XCTFail("cp.resume() failed - \(err)")
        }

        sleep(1)

        XCTAssertNotNil(service.serviceId)
        server.setProperty(udn: udn, serviceId: service.serviceId!, properties: properties) {
            subscription, error in
            if let error = error {
                XCTFail("set property error - \(error)")
                return
            }
        }

        sleep(1)

        // ---------------------------
        
        XCTAssertFalse(handledService.isEmpty)
        XCTAssertFalse(handledEvents.isEmpty)
        XCTAssertEqual(4, handledEvents.count)

        cp.finish()

        usleep(500 * 1000)
        XCTAssertFalse(cp.running)
    }

    /**
     suspend resume timeout
     */
    func helperControlPointSuspendResumeTimeout(st: String, serviceType: String, server: UPnPServer, udn: String, service: UPnPService, properties: [String:String]) -> Void {
        let cp = UPnPControlPoint()
        cp.monitor(name: "cp-monitor", handler: controlpointMonitoringHandler)

        var handledService = [UPnPService]()
        var handledEvents = [UPnPEventSubscriber]()

        var serviceId: String? = nil

        cp.on(scpd: {
                  (device, service, scpd, error) in
                  
                  guard let x = device?.udn, x == udn, service?.serviceType == serviceType else {
                      //                unexpected device
                      return
                  }

                  guard error == nil else {
                      // error
                      XCTFail("error - \(error!)")
                      return
                  }

                  guard let service = service else {
                      // error
                      return
                  }

                  guard service.serviceType == serviceType else {
                      // not expected service
                      return
                  }

                  serviceId = service.serviceId

                  guard let device = device, let udn = device.udn else {
                      // error
                      return
                  }

                  if cp.getEventSubscribers(forUdn: udn).isEmpty {
                      do {
                          try cp.subscribe(
                            udn: udn,
                            service: service,
                            completionHandler: {
                                (subscriber, error) in
                                XCTAssertNil(error)
                                guard let subscriber = subscriber else {
                                    XCTFail("No Subscriber")
                                    return
                                }
                                XCTAssertNotNil(subscriber.sid)
                                print("[SUBSCRIBE] result (SID: '\(subscriber.sid!)')")

                                subscriber.onNotification {
                                    (subscriber, properties, error) in
                                    guard let subscriber = subscriber else {
                                        XCTFail("subscriber is nil")
                                        return
                                    }
                                    print("SID - '\(subscriber.sid ?? "nil")'\n\(properties?.description ?? "nil")")
                                    handledEvents.append(subscriber)
                                }
                            })
                      } catch {
                          XCTFail("failed - \(error)")
                          return
                      }
                  }

                  handledService.append(service)
              })

        cp.on(eventProperties: {
                  (subscriber, props, error) in

                  guard error == nil else {
                      print("[EVENT] Notification Handling Error - \(error!)")
                      return
                  }
                  
                  guard let subscriber = subscriber else {
                      XCTFail("subscriber is nil")
                      return
                  }

                  print("ON EVENT - SID: \(subscriber.sid ?? "(no sid)") , SEQ: \(subscriber.seq)")

                  XCTAssertNotNil(properties)
                  guard let props = props else {
                      return
                  }

                  XCTAssertEqual(properties.count, props.fields.count)

                  XCTAssertNotNil(subscriber.sid)
                  print("x [EVENT] Notification (SID: '\(subscriber.sid!)')")
                  for field in props.fields {
                      print("- Property - '\(field.key)': '\(field.value)'")
                      XCTAssertNotNil(properties[field.key])
                      XCTAssertEqual(properties[field.key]!, field.value)
                  }

                  handledEvents.append(subscriber)
              })

        do {
            try cp.run()
            sleep(2)
        } catch let e {
            XCTFail("cp.run() failed \(e)")
            return
        }

        cp.sendMsearch(st: st, mx: 3)

        sleep(3)

        XCTAssertNotNil(service.serviceId)
        server.setProperty(udn: udn, serviceId: service.serviceId!, properties: properties) {
            subscription, error in
            if let error = error {
                XCTFail("set property error - \(error)")
                return
            }
        }

        sleep(1)

        XCTAssertNotNil(serviceId)
        if let serviceId = serviceId {
            XCTAssertFalse(cp.getEventSubscribers(forServiceId: serviceId).isEmpty)
        }


        // ----------------------

        cp.suspend()

        sleep(1)

        for (_, device) in cp.presentableDevices {
            device.timeBase.tick = .now() - .seconds(50 * 60)
        }

        for subscriber in cp.eventSubscribers.list {
            subscriber.tick = .now() - .seconds(50 * 60)
        }

        do {
            try cp.resume()
        } catch let err {
            XCTFail("cp.resume() failed - \(err)")
        }

        sleep(1)

        XCTAssertNotNil(service.serviceId)
        server.setProperty(udn: udn, serviceId: service.serviceId!, properties: properties) {
            subscription, error in
            if let error = error {
                XCTFail("set property error - \(error)")
                return
            }
        }

        sleep(1)

        // ---------------------------
        
        XCTAssertFalse(handledService.isEmpty)
        XCTAssertFalse(handledEvents.isEmpty)
        XCTAssertEqual(4, handledEvents.count)

        cp.finish()

        usleep(500 * 1000)
        XCTAssertFalse(cp.running)
    }

    /**
     all tests
     */
    static var allTests = [
      ("testNotify", testNotify),
      ("testServer", testServer),
      ("testControlPoint", testControlPoint),
    ]

    /**
     device description urn:schemas-upnp-org:device:DimmableLight:1
     */
    static var deviceDescription_DimmableLight = "<?xml version=\"1.0\"?>" +
      "<root xmlns=\"urn:schemas-upnp-org:device-1-0\">" +
      "  <specVersion>" +
      "  <major>1</major>" +
      "  <minor>0</minor>" +
      "  </specVersion>" +
      "  <device>" +
      "  <deviceType>urn:schemas-upnp-org:device:DimmableLight:1</deviceType>" +
      "  <friendlyName>UPnP Sample Dimmable Light ver.1</friendlyName>" +
      "  <manufacturer>Testers</manufacturer>" +
      "  <manufacturerURL>www.example.com</manufacturerURL>" +
      "  <modelDescription>UPnP Test Device</modelDescription>" +
      "  <modelName>UPnP Test Device</modelName>" +
      "  <modelNumber>1</modelNumber>" +
      "  <modelURL>www.example.com</modelURL>" +
      "  <serialNumber>12345678</serialNumber>" +
      "  <UDN>uuid:e399855c-7ecb-1fff-8000-000000000000</UDN>" +
      "  <serviceList>" +
      "    <service>" +
      "    <serviceType>urn:schemas-upnp-org:service:SwitchPower:1</serviceType>" +
      "    <serviceId>urn:upnp-org:serviceId:SwitchPower.1</serviceId>" +
      "    <SCPDURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/scpd.xml</SCPDURL>" +
      "    <controlURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/control.xml</controlURL>" +
      "    <eventSubURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:SwitchPower:1/event.xml</eventSubURL>" +
      "    </service>" +
      "    <service>" +
      "    <serviceType>urn:schemas-upnp-org:service:Dimming:1</serviceType>" +
      "    <serviceId>urn:upnp-org:serviceId:Dimming.1</serviceId>" +
      "    <SCPDURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:Dimming:1/scpd.xml</SCPDURL>" +
      "    <controlURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:Dimming:1/control.xml</controlURL>" +
      "    <eventSubURL>/e399855c-7ecb-1fff-8000-000000000000/urn:schemas-upnp-org:service:Dimming:1/event.xml</eventSubURL>" +
      "    </service>" +
      "  </serviceList>" +
      "  </device>" +
      "</root>"

    /**
     scpd urn:schemas-upnp-org:service:SwitchPower:1
     */
    static var scpd_SwitchPower = "<?xml version=\"1.0\"?>" +
      "<scpd xmlns=\"urn:schemas-upnp-org:service-1-0\">" +
      "  <specVersion>" +
      " <major>1</major>" +
      " <minor>0</minor>" +
      "  </specVersion>" +
      "  <actionList>" +
      " <action>" +
      "   <name>SetLoadLevelTarget</name>" +
      "   <argumentList>" +
      "  <argument>" +
      "    <name>newLoadlevelTarget</name>" +
      "    <direction>in</direction>" +
      "    <relatedStateVariable>LoadLevelTarget</relatedStateVariable>" +
      "  </argument>" +
      "   </argumentList>" +
      " </action>" +
      " <action>" +
      "   <name>GetLoadLevelTarget</name>" +
      "   <argumentList>" +
      "  <argument>" +
      "    <name>GetLoadlevelTarget</name>" +
      "    <direction>out</direction>" +
      "    <relatedStateVariable>LoadLevelTarget</relatedStateVariable>" +
      "  </argument>" +
      "   </argumentList>" +
      " </action>" +
      " <action>" +
      "   <name>GetLoadLevelStatus</name>" +
      "   <argumentList>" +
      "  <argument>" +
      "    <name>retLoadlevelStatus</name>" +
      "    <direction>out</direction>" +
      "    <relatedStateVariable>LoadLevelStatus</relatedStateVariable>" +
      "  </argument>" +
      "   </argumentList>" +
      " </action>" +
      "  </actionList>" +
      "  <serviceStateTable>" +
      " <stateVariable sendEvents=\"no\">" +
      "   <name>LoadLevelTarget</name>" +
      "   <dataType>ui1</dataType>" +
      " </stateVariable>" +
      " <stateVariable sendEvents=\"yes\">" +
      "   <name>LoadLevelStatus</name>" +
      "   <dataType>ui1</dataType>" +
      " </stateVariable>" +
      "  </serviceStateTable>" +
      "</scpd>"
}
