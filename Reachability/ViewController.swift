//
//  ViewController.swift
//  Reachability
//
//  Created by Sathish on 8/26/15.
//  Copyright © 2015 Sathish. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet var summaryLabel: UILabel!
    
    @IBOutlet var remoteHostLabel: UITextField!
    @IBOutlet var remoteHostImageView: UIImageView!
    @IBOutlet var remoteHostStatusField: UITextField!
    
    @IBOutlet var internetConnectionImageView: UIImageView!
    @IBOutlet var internetConnectionStatusField: UITextField!
    
    @IBOutlet var localWiFiConnectionImageView: UIImageView!
    @IBOutlet var localWiFiConnectionStatusField: UITextField!
    
    var hostReachability: Reachability!
    var internetReachability: Reachability!
    var wifiReachability: Reachability!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.summaryLabel.hidden = true
        
        /*
        Observe the kNetworkReachabilityChangedNotification. When that notification is posted, the method reachabilityChanged will be called.
        */
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("reachabilityChanged:"), name: kReachabilityChangedNotification, object: nil)
        
        
        //Change the host name here to change the server you want to monitor.
        let remoteHostName: String = "www.apple.com"
        let remoteHostLabelFormatString: String = NSLocalizedString("Remote Host: %@", comment:"Remote host label format string")
        self.remoteHostLabel.text = NSString(format: remoteHostLabelFormatString, remoteHostName) as String
        
        self.hostReachability = Reachability.reachabilityWithHostName(remoteHostName)
        self.hostReachability._reachabilityType = .hostReachability
        self.hostReachability.startNotifier()
        self.updateInterfaceWithReachability(.hostReachability)
        
        self.internetReachability = Reachability.reachabilityForInternetConnection()
        self.internetReachability._reachabilityType = .internetReachability
        self.internetReachability.startNotifier()
        self.updateInterfaceWithReachability(.internetReachability)
        
        self.wifiReachability = Reachability.reachabilityForLocalWiFi()
        self.wifiReachability._reachabilityType = .wifiReachability
        self.wifiReachability.startNotifier()
        self.updateInterfaceWithReachability(.wifiReachability)
    }
    
    /*!
    * Called by Reachability whenever status changes.
    */
    func reachabilityChanged(note: NSNotification) {
        //let currentType: NSString = note.object as! NSString
        //let curReach: ReachabilityType = ReachabilityType(rawValue: currentType as String)!
        //self.updateInterfaceWithReachability(curReach)
        self.updateInterfaceWithReachability(.hostReachability)
        self.updateInterfaceWithReachability(.internetReachability)
        self.updateInterfaceWithReachability(.wifiReachability)
    }
    
    func updateInterfaceWithReachability(reachability: ReachabilityType) {
        if (reachability == .hostReachability) {
            self.configureTextField(self.remoteHostStatusField, imageView: self.remoteHostImageView, reachability: self.hostReachability)
            let netStatus: NetworkStatus = self.hostReachability.currentReachabilityStatus()
            let connectionRequired: Bool = self.hostReachability.connectionRequired()
            
            self.summaryLabel.hidden = (netStatus != .ReachableViaWWAN)
            var baseLabelText: String = ""
            
            if (connectionRequired) {
                baseLabelText = NSLocalizedString("Cellular data network is available.\nInternet traffic will be routed through it after a connection is established.", comment: "Reachability text if a connection is required")
            } else {
                baseLabelText = NSLocalizedString("Cellular data network is active.\nInternet traffic will be routed through it.", comment: "Reachability text if a connection is not required")
            }
            self.summaryLabel.text = baseLabelText
        }
        
        if (self.internetReachability != nil && reachability == .internetReachability) {
            self.configureTextField(self.internetConnectionStatusField, imageView: self.internetConnectionImageView, reachability: self.internetReachability)
        }
        
        if (self.wifiReachability != nil && reachability == .wifiReachability) {
            self.configureTextField(self.localWiFiConnectionStatusField, imageView: self.localWiFiConnectionImageView, reachability: self.wifiReachability)
        }
    }
    
    func configureTextField(textField: UITextField, imageView: UIImageView, reachability: Reachability) {
        let netStatus: NetworkStatus = reachability.currentReachabilityStatus()
        var connectionRequired: Bool = reachability.connectionRequired()
        var statusString: NSString = ""
        
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
            let connectionRequiredFormatString: NSString = NSLocalizedString("%@, Connection Required", comment: "Concatenation of status string with connection requirement")
            statusString = NSString(format: connectionRequiredFormatString, statusString)
        }
        textField.text = statusString as String
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

