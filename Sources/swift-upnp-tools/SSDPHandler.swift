import SwiftHttpServer

public typealias SSDPHeaderHandler = ((hostname:String, port: Int32)?, SSDPHeader?) -> [SSDPHeader]?

