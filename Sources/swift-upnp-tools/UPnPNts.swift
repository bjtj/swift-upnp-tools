//
// NTS.swift
// 


/**
 UPnP NTS (Notification Types)
 */
public enum UPnPNts: String {
    case alive = "ssdp:alive"
    case update = "ssdp:update"
    case byebye = "ssdp:byebye"
}
