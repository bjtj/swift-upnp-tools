//
// SSDPHandler.swift
// 

import SwiftHttpServer

/**
 Handler Type
 */
public typealias SSDPHeaderHandler = ((hostname:String, port: Int32)?, SSDPHeader?) -> [SSDPHeader]?

