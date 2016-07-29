//
//  Reachability.swift
//  Reachability
//
// Copyright (c) 2015 Sathish Kumar
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit
import SystemConfiguration
import Foundation

enum NetworkStatus: Int {
  case NotReachable = 0
  case ReachableViaWiFi
  case ReachableViaWWAN
}

enum ReachabilityType: String {
  case hostReachability = "host"
  case internetReachability = "internet"
  case wifiReachability = "wifi"
}

let kReachabilityChangedNotification = "kNetworkReachabilityChangedNotification"

var kShouldPrintReachabilityFlags: Bool {
  return true
}

func PrintReachabilityFlags(flags: SCNetworkReachabilityFlags, comment: NSString) {
  guard kShouldPrintReachabilityFlags else {
    return
  }
  print("Reachability Flag Status: %@%@ %@%@%@%@%@%@%@ %@\n",
        (flags == .IsWWAN)			         ? "W" : "-",
        (flags == .Reachable)            ? "R" : "-",
        (flags == .TransientConnection)  ? "t" : "-",
        (flags == .ConnectionRequired)   ? "c" : "-",
        (flags == .ConnectionOnTraffic)  ? "C" : "-",
        (flags == .InterventionRequired) ? "i" : "-",
        (flags == .ConnectionOnDemand)   ? "D" : "-",
        (flags == .IsLocalAddress)       ? "l" : "-",
        (flags == .IsDirect)             ? "d" : "-",
        comment
  )
}

func ReachabilityCallback(target: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutablePointer<Void>) {
  NSNotificationCenter.defaultCenter().postNotificationName(kReachabilityChangedNotification, object: nil)
}

class Reachability {
  
  var alwaysReturnLocalWiFiStatus = false
  var reachabilityRef: SCNetworkReachabilityRef? = nil
  var reachabilityType: ReachabilityType!
  
  class func reachabilityWithHostName(hostName: String) -> Reachability? {
    guard let networkReachability = SCNetworkReachabilityCreateWithName(nil, hostName) else {
      return nil
    }
    let reachability = Reachability()
    reachability.reachabilityRef = networkReachability
    reachability.alwaysReturnLocalWiFiStatus = false
    return reachability
  }
  
  class func reachabilityWithAddress(hostAddress: UnsafePointer<sockaddr_in>) -> Reachability? {
    guard let networkReachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, UnsafePointer<sockaddr>(hostAddress)) else {
      return nil
    }
    let reachability = Reachability()
    reachability.reachabilityRef = networkReachability
    reachability.alwaysReturnLocalWiFiStatus = false
    return reachability
  }
  
  class func reachabilityForInternetConnection() -> Reachability? {
    var zeroAddress: sockaddr_in = sockaddr_in()
    bzero(&zeroAddress, sizeofValue(zeroAddress))
    zeroAddress.sin_len = __uint8_t(sizeofValue(zeroAddress))
    zeroAddress.sin_family = sa_family_t(AF_INET)
    return reachabilityWithAddress(&zeroAddress)
  }
  
  class func reachabilityForLocalWiFi() -> Reachability? {
    var localWifiAddress: sockaddr_in = sockaddr_in()
    bzero(&localWifiAddress, sizeofValue(localWifiAddress))
    localWifiAddress.sin_len = __uint8_t(sizeofValue(localWifiAddress))
    localWifiAddress.sin_family = sa_family_t(AF_INET)
    localWifiAddress.sin_addr.s_addr = __uint32_t(0xA9FE0000)
    
    guard let reachability = reachabilityWithAddress(&localWifiAddress) else {
      return nil
    }
    reachability.alwaysReturnLocalWiFiStatus = true
    return reachability
  }
  
  func startNotifier() -> (Bool) {
    var context = SCNetworkReachabilityContext()
    context.version = 0
    context.info = UnsafeMutablePointer<Void>(Unmanaged<NSString>.passRetained(reachabilityType.rawValue).toOpaque())
    guard let reachabilityRef = reachabilityRef where SCNetworkReachabilitySetCallback(reachabilityRef, ReachabilityCallback, &context) else {
      return false
    }
    return SCNetworkReachabilityScheduleWithRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)
  }
  
  func stopNotifier() {
    guard let reachabilityRef = reachabilityRef else {
      return
    }
    SCNetworkReachabilityUnscheduleFromRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)
  }
  
  func localWiFiStatusForFlags(flags: SCNetworkReachabilityFlags) -> NetworkStatus {
    PrintReachabilityFlags(flags, comment: "localWiFiStatusForFlags")
    guard flags == .Reachable && flags == .IsDirect else {
      return .NotReachable
    }
    return .ReachableViaWiFi
  }
  
  func networkStatusForFlags(flags: SCNetworkReachabilityFlags) -> NetworkStatus {
    PrintReachabilityFlags(flags, comment: "networkStatusForFlags")
    if flags.rawValue & SCNetworkReachabilityFlags.Reachable.rawValue == 0 {
      // The target host is not reachable.
      return .NotReachable
    }
    
    var returnValue: NetworkStatus = .NotReachable
    
    if (flags.rawValue & SCNetworkReachabilityFlags.ConnectionRequired.rawValue) == 0 {
      /*
       If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
       */
      returnValue = .ReachableViaWiFi
    }
    
    if ((((flags.rawValue & SCNetworkReachabilityFlags.ConnectionOnDemand.rawValue) != 0) || (flags.rawValue & SCNetworkReachabilityFlags.ConnectionOnTraffic.rawValue) != 0)) {
      /*
       ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
       */
      
      if ((flags.rawValue & SCNetworkReachabilityFlags.InterventionRequired.rawValue) == 0) {
        /*
         ... and no [user] intervention is needed...
         */
        returnValue = .ReachableViaWiFi
      }
    }
    
    if ((flags.rawValue & SCNetworkReachabilityFlags.IsWWAN.rawValue) == SCNetworkReachabilityFlags.IsWWAN.rawValue) {
      /*
       ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
       */
      returnValue = .ReachableViaWWAN
    }
    
    return returnValue
  }
  
  func connectionRequired() -> Bool {
    var flags = SCNetworkReachabilityFlags()
    guard let reachabilityRef = reachabilityRef where (SCNetworkReachabilityGetFlags(reachabilityRef, &flags)) else {
      return false
    }
    return (flags.rawValue & SCNetworkReachabilityFlags.ConnectionRequired.rawValue) == 1 ? true : false
  }
  
  func currentReachabilityStatus() -> NetworkStatus {
    var flags = SCNetworkReachabilityFlags()
    guard let reachabilityRef = reachabilityRef where (SCNetworkReachabilityGetFlags(reachabilityRef, &flags)) else {
      return .NotReachable
    }
    guard alwaysReturnLocalWiFiStatus else {
      return localWiFiStatusForFlags(flags)
    }
    return networkStatusForFlags(flags)
  }
}

