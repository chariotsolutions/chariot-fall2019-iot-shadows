//
//  ViewController.swift
//  ChariotFall2019
//
//  Created by Steven Smith on 8/29/19.
//  Copyright © 2019 Steven Smith. All rights reserved.
//

import UIKit
import AWSMobileClient
import AWSIoT

class ViewController: UIViewController {
    
    private let ioDataManangerName = "FallAWSIoTDataManager"
    private var iotDataManager: AWSIoTDataManager?
    
    private var temperature: Double = 0.0 {
        didSet {
            lblTemp.text = String(format: "%.2f", temperature)
        }
    }
    private var humidity: Double = 0.0 {
        didSet {
            lblHumidity.text = String(format: "%.2f", humidity)
        }
    }
    private var ledValue: Int = 0 {
        didSet {
            lblLedValue.text = "\(ledValue)"
        }
    }
    private var isLedOn = false {
        didSet {
            swLed.isOn = isLedOn
        }
    }
    
    private var observers = [NSKeyValueObservation]()
    
    @IBOutlet weak var lblTemp: UILabel!
    @IBOutlet weak var lblHumidity: UILabel!
    @IBOutlet weak var lblLedValue: UILabel!
    @IBOutlet weak var swLed: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AWSMobileClient.sharedInstance().initialize { (userState, error) in
            if let userState = userState {
                print("UserState: \(userState.rawValue)")
                switch userState {
                case .signedIn:
                    print("Identity: \(AWSMobileClient.sharedInstance().getIdentityId())");
                    self.authenticated()
                case .signedOut, .signedOutFederatedTokensInvalid, .signedOutUserPoolsTokenInvalid:
                    self.signIn()
                default:
                    print("something unexpected")
                    return
                }
            } else if let error = error {
                print("error: \(error.localizedDescription)")
            }
        }
    }
    
    
    @IBAction func toggleLedPower(_ sender: Any) {
        guard let uiSwitch = sender as? UISwitch else {
            return
        }
        IoTDataManager.shared.publishUpdateLedPower(uiSwitch.isOn)
    }
    
    private func authenticated() {
        self.addObservers()
        IoTDataManager.shared.startObservingShadow()
    }
    
    private func signIn() {
        AWSMobileClient.sharedInstance().showSignIn(navigationController: self.navigationController!, { (signInState, error) in
            if let signInState = signInState {
                print("Sign in flow completed: \(signInState)")
                if case .signedIn = signInState {
                    self.authenticated()
                }
            } else if let error = error {
                print("error logging in: \(error.localizedDescription)")
            }
        })
    }
    
    private func addObservers() {
        observers = [
            IoTDataManager.shared.observe(\.temperature, options: [.old, .new]) { (iotDataManager, change) in
                guard let newTemp = change.newValue else {
                    return
                }
                self.temperature = newTemp
            },
            IoTDataManager.shared.observe(\.humidity, options: [.old, .new]) { (iotDataManager, change) in
                guard let newHumidity = change.newValue else {
                    return
                }
                self.humidity = newHumidity
            },
            IoTDataManager.shared.observe(\.ledValue, options: [.old, .new]) { (iotDataManager, change) in
                guard let newLedValue = change.newValue else {
                    return
                }
                self.ledValue = newLedValue
            },
            IoTDataManager.shared.observe(\.isLedOn, options: [.old, .new]) { (iotDataManager, change) in
                guard let newLedIsOn = change.newValue else {
                    return
                }
                self.isLedOn = newLedIsOn
            }
        ]
    }
    
    private func cleanupObservers() {
        for observer in observers {
            observer.invalidate()
        }
    }
}

