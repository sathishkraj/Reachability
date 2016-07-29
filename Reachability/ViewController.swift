//
//  ViewController.swift
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

struct Constants {
  static let remoteHostName = "www.apple.com"
}

extension Selector {
  static let ReachabilityChanged = #selector(ViewController.reachabilityChanged(_:))
}

class ViewController: UIViewController {
  
  @IBOutlet weak var summaryLabel: UILabel!
  
  @IBOutlet weak var remoteHostLabel: UITextField!
  @IBOutlet weak var remoteHostImageView: UIImageView!
  @IBOutlet weak var remoteHostStatusField: UITextField!
  
  @IBOutlet weak var internetConnectionImageView: UIImageView!
  @IBOutlet weak var internetConnectionStatusField: UITextField!
  
  @IBOutlet weak var localWiFiConnectionImageView: UIImageView!
  @IBOutlet weak var localWiFiConnectionStatusField: UITextField!
  
  var hostReachability: Reachability!
  var internetReachability: Reachability!
  var wifiReachability: Reachability!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    summaryLabel.hidden = true
    
    //Change the host name here to change the server you want to monitor.
    let remoteHostLabelFormatString = NSLocalizedString("Remote Host: %@", comment:"Remote host label format string")
    remoteHostLabel.text = String(format: remoteHostLabelFormatString, Constants.remoteHostName)
    
    addReachibilityObserver()
    createReachability()
  }
  
  func addReachibilityObserver() {
    /*
     Observe the kNetworkReachabilityChangedNotification. When that notification is posted, the method reachabilityChanged will be called.
     */
    NSNotificationCenter.defaultCenter().addObserver(self, selector: .ReachabilityChanged, name: kReachabilityChangedNotification, object: nil)
  }
  
  func createReachability() {
    hostReachability = Reachability.reachabilityWithHostName(Constants.remoteHostName)
    hostReachability.reachabilityType = .hostReachability
    hostReachability.startNotifier()
    updateInterfaceWithReachability(.hostReachability)
    
    internetReachability = Reachability.reachabilityForInternetConnection()
    internetReachability.reachabilityType = .internetReachability
    internetReachability.startNotifier()
    updateInterfaceWithReachability(.internetReachability)
    
    wifiReachability = Reachability.reachabilityForLocalWiFi()
    wifiReachability.reachabilityType = .wifiReachability
    wifiReachability.startNotifier()
    updateInterfaceWithReachability(.wifiReachability)
  }
  
  /*!
   * Called by Reachability whenever status changes.
   */
  func reachabilityChanged(note: NSNotification) {
    //let currentType: NSString = note.object as! NSString
    //let curReach: ReachabilityType = ReachabilityType(rawValue: currentType as String)!
    //self.updateInterfaceWithReachability(curReach)
    updateInterfaceWithReachability(.hostReachability)
    updateInterfaceWithReachability(.internetReachability)
    updateInterfaceWithReachability(.wifiReachability)
  }
  
  func updateInterfaceWithReachability(reachability: ReachabilityType) {
    if reachability == .hostReachability {
      configureTextField(remoteHostStatusField, imageView: remoteHostImageView, reachability: hostReachability)
      let netStatus = hostReachability.currentReachabilityStatus()
      let connectionRequired = hostReachability.connectionRequired()
      
      summaryLabel.hidden = netStatus != .ReachableViaWWAN
      
      guard connectionRequired else {
        summaryLabel.text = NSLocalizedString("Cellular data network is active.\nInternet traffic will be routed through it.", comment: "Reachability text if a connection is not required")
        return
      }
      summaryLabel.text = NSLocalizedString("Cellular data network is available.\nInternet traffic will be routed through it after a connection is established.", comment: "Reachability text if a connection is required")
    }
    
    if let _ = internetReachability where reachability == .internetReachability {
      configureTextField(internetConnectionStatusField, imageView: internetConnectionImageView, reachability: internetReachability)
    }
    
    if let _ = wifiReachability where reachability == .wifiReachability {
      configureTextField(localWiFiConnectionStatusField, imageView: localWiFiConnectionImageView, reachability: wifiReachability)
    }
  }
  
  func configureTextField(textField: UITextField, imageView: UIImageView, reachability: Reachability) {
    let netStatus = reachability.currentReachabilityStatus()
    var connectionRequired = reachability.connectionRequired()
    var statusString = ""
    
    switch (netStatus) {
    case .NotReachable:
      statusString = NSLocalizedString("Access Not Available", comment:"Text field text for access is not available")
      imageView.image = UIImage(named: "stop-32.png")
      /*
       Minor interface detail- connectionRequired may return YES even when the host is unreachable. We cover that up here...
       */
      connectionRequired = false
    case .ReachableViaWWAN:
      statusString = NSLocalizedString("Reachable WWAN", comment: "")
      imageView.image = UIImage(named:"WWAN5.png")
    case .ReachableViaWiFi:
      statusString = NSLocalizedString("Reachable WiFi", comment: "")
      imageView.image = UIImage(named:"Airport.png")
    }
    
    if (connectionRequired) {
      let connectionRequiredFormatString = NSLocalizedString("%@, Connection Required", comment: "Concatenation of status string with connection requirement")
      statusString = String(format: connectionRequiredFormatString, statusString)
    }
    textField.text = statusString
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  
}

