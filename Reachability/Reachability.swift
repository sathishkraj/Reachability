//
//  Reachability.swift
//  Reachability
//
//  Created by Sathish on 8/26/15.
//  Copyright © 2015 Apple Inc. All rights reserved.
//

import UIKit
import SystemConfiguration
import Foundation

enum NetworkStatus: NSInteger {
    case NotReachable = 0
    case ReachableViaWiFi
    case ReachableViaWWAN
}

enum ReachabilityType: String {
    case hostReachability = "host"
    case internetReachability = "internet"
    case wifiReachability = "wifi"
}

public let kReachabilityChangedNotification: String = "kNetworkReachabilityChangedNotification";

public func kShouldPrintReachabilityFlags() -> (Bool) {
    return true
}

public func PrintReachabilityFlags(flags: SCNetworkReachabilityFlags, comment: NSString) -> () {
    if kShouldPrintReachabilityFlags() {
        NSLog("Reachability Flag Status: %@%@ %@%@%@%@%@%@%@ %@\n",
            (flags.rawValue == SCNetworkReachabilityFlags.IsWWAN.rawValue)			     ? "W" : "-",
            (flags.rawValue == SCNetworkReachabilityFlags.Reachable.rawValue)            ? "R" : "-",
            (flags.rawValue == SCNetworkReachabilityFlags.TransientConnection.rawValue)  ? "t" : "-",
            (flags.rawValue == SCNetworkReachabilityFlags.ConnectionRequired.rawValue)   ? "c" : "-",
            (flags.rawValue == SCNetworkReachabilityFlags.ConnectionOnTraffic.rawValue)  ? "C" : "-",
            (flags.rawValue == SCNetworkReachabilityFlags.InterventionRequired.rawValue) ? "i" : "-",
            (flags.rawValue == SCNetworkReachabilityFlags.ConnectionOnDemand.rawValue)   ? "D" : "-",
            (flags.rawValue == SCNetworkReachabilityFlags.IsLocalAddress.rawValue)       ? "l" : "-",
            (flags.rawValue == SCNetworkReachabilityFlags.IsDirect.rawValue)             ? "d" : "-",
            comment
        );
    }
}

func ReachabilityCallback(target: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutablePointer<Void>) -> Void {
//    assert(info != nil, "info is nill in reachability callback")
//    var infoObject: NSString? = nil
//    if info != nil {
//        infoObject = Unmanaged<NSString>.fromOpaque(COpaquePointer(info)).takeRetainedValue()
//    }
//    
//    if infoObject != nil {
//        assert(infoObject!.isKindOfClass(NSString), "info is wrong class in reachability callback")
//    }
    NSNotificationCenter.defaultCenter().postNotificationName(kReachabilityChangedNotification, object: nil)
}

class Reachability: NSObject {
    
    var _alwaysReturnLocalWiFiStatus: Bool = false
    var _reachabilityRef: SCNetworkReachabilityRef? = nil
    var _reachabilityType: ReachabilityType!
    
    class func reachabilityWithHostName(hostName: String) -> Reachability {
        var returnValue: Reachability? = nil
        let reachability: SCNetworkReachabilityRef? = SCNetworkReachabilityCreateWithName(nil, hostName)
        if reachability != nil {
            returnValue = Reachability()
            if returnValue != nil {
                returnValue!._reachabilityRef = reachability
                returnValue!._alwaysReturnLocalWiFiStatus = false
            }
        }
        return returnValue!
    }
    
    class func reachabilityWithAddress(hostAddress: UnsafePointer<sockaddr_in>) -> Reachability {
        var returnValue: Reachability? = nil
        let reachability: SCNetworkReachabilityRef? = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, UnsafePointer<sockaddr>(hostAddress))
        if reachability != nil {
            returnValue = Reachability()
            if returnValue != nil {
                returnValue!._reachabilityRef = reachability
                returnValue!._alwaysReturnLocalWiFiStatus = false
            }
        }
        return returnValue!
    }
    
    class func reachabilityForInternetConnection() -> Reachability {
        var zeroAddress: sockaddr_in = sockaddr_in()
        bzero(&zeroAddress, sizeofValue(zeroAddress))
        zeroAddress.sin_len = __uint8_t(sizeofValue(zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        return self.reachabilityWithAddress(&zeroAddress)
    }
    
    class func reachabilityForLocalWiFi() -> Reachability {
        var localWifiAddress: sockaddr_in = sockaddr_in()
        bzero(&localWifiAddress, sizeofValue(localWifiAddress))
        localWifiAddress.sin_len = __uint8_t(sizeofValue(localWifiAddress))
        localWifiAddress.sin_family = sa_family_t(AF_INET)
        localWifiAddress.sin_addr.s_addr = __uint32_t(0xA9FE0000)
        
        let returnValue: Reachability? = self.reachabilityWithAddress(&localWifiAddress)
        if returnValue != nil {
            returnValue!._alwaysReturnLocalWiFiStatus = true
        }
        
        return returnValue!
    }
    
    func startNotifier() -> (Bool) {
        var returnValue: Bool = false;
        let version: Int = 0
        var context: SCNetworkReachabilityContext = SCNetworkReachabilityContext()
        context.version = version
        let info: UnsafeMutablePointer<Void> = UnsafeMutablePointer<Void>(Unmanaged<NSString>.passRetained(self._reachabilityType.rawValue).toOpaque())
        context.info = info
        if SCNetworkReachabilitySetCallback(self._reachabilityRef!, ReachabilityCallback, &context) {
            if SCNetworkReachabilityScheduleWithRunLoop(self._reachabilityRef!, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode) {
                returnValue = true
            }
        }
        
        return returnValue;
    }
    
    func stopNotifier() {
        if (self._reachabilityRef != nil) {
            SCNetworkReachabilityUnscheduleFromRunLoop(self._reachabilityRef!, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        }
    }
    
    func localWiFiStatusForFlags(flags: SCNetworkReachabilityFlags) -> (NetworkStatus) {
        PrintReachabilityFlags(flags, comment: "localWiFiStatusForFlags")
        var returnValue: NetworkStatus = .NotReachable
        
        if (flags == SCNetworkReachabilityFlags.Reachable) && (flags == SCNetworkReachabilityFlags.IsDirect)
        {
            returnValue = .ReachableViaWiFi
        }
        
        return returnValue;
    }
    
    func networkStatusForFlags(flags: SCNetworkReachabilityFlags) -> (NetworkStatus) {
        
        PrintReachabilityFlags(flags, comment: "networkStatusForFlags");
        if flags.rawValue & SCNetworkReachabilityFlags.Reachable.rawValue == 0 {
            // The target host is not reachable.
            return .NotReachable;
        }
        
        var returnValue: NetworkStatus = .NotReachable;
        
        if (flags.rawValue & SCNetworkReachabilityFlags.ConnectionRequired.rawValue) == 0 {
            /*
            If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
            */
            returnValue = .ReachableViaWiFi;
        }
        
        if ((((flags.rawValue & SCNetworkReachabilityFlags.ConnectionOnDemand.rawValue) != 0) || (flags.rawValue & SCNetworkReachabilityFlags.ConnectionOnTraffic.rawValue) != 0)) {
            /*
            ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
            */
            
            if ((flags.rawValue & SCNetworkReachabilityFlags.InterventionRequired.rawValue) == 0) {
                /*
                ... and no [user] intervention is needed...
                */
                returnValue = .ReachableViaWiFi;
            }
        }
        
        if ((flags.rawValue & SCNetworkReachabilityFlags.IsWWAN.rawValue) == SCNetworkReachabilityFlags.IsWWAN.rawValue) {
            /*
            ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
            */
            returnValue = .ReachableViaWWAN;
        }
        
        return returnValue;
    }
    
    func connectionRequired() -> (Bool) {
        assert(self._reachabilityRef != nil, "connectionRequired called with NULL reachabilityRef")
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags()
        
        if (SCNetworkReachabilityGetFlags(self._reachabilityRef!, &flags))
        {
            return (flags.rawValue & SCNetworkReachabilityFlags.ConnectionRequired.rawValue) == 1 ? true : false
        }
        
        return false;
    }
    
    func currentReachabilityStatus() -> (NetworkStatus) {
        assert(self._reachabilityRef != nil, "currentNetworkStatus called with NULL SCNetworkReachabilityRef")
        var returnValue: NetworkStatus = .NotReachable
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags()
        
        if (SCNetworkReachabilityGetFlags(self._reachabilityRef!, &flags))
        {
            if (_alwaysReturnLocalWiFiStatus)
            {
                returnValue = self.localWiFiStatusForFlags(flags)
            }
            else
            {
                returnValue = self.networkStatusForFlags(flags)
            }
        }
        
        return returnValue;
    }
}
