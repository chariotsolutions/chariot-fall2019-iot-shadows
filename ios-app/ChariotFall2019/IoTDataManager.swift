//
//  IoTDataManager.swift
//  ChariotFall2019
//
//  Created by Steven Smith on 9/11/19.
//  Copyright © 2019 Steven Smith. All rights reserved.
//

import Foundation
import AWSIoT
import AWSMobileClient

@objc class IoTDataManager: NSObject {
    static let shared = IoTDataManager()
    
    @objc dynamic var temperature: Double = 0.0
    @objc dynamic var humidity: Double = 0.0
    @objc dynamic var ledValue: Int = 0
    @objc dynamic var isLedOn = false
    
    private var iotDataManager: AWSIoTDataManager?
    private let ioDataManangerName = "FallAWSIoTDataManager"
    private let deviceName = "<PUT YOUR DEVICE NAME/ID HERE>"
    
    private override init() { }
    
    func startObservingShadow() {
        initializeIoTDataManager()
        connectToMqtt()
    }
    
    func publishUpdateLedPower(_ isOn: Bool) {
        guard let iotDataManager = iotDataManager else {
            return
        }
        let value = isOn ? 100 : 0
        let message = "{ \"state\": { \"desired\": { \"led\": \(value) } } }"
        iotDataManager.publishString(message, onTopic: "$aws/things/\(deviceName)/shadow/update", qoS:.messageDeliveryAttemptedAtMostOnce)
    }
    
    private func initializeIoTDataManager() {
        let iotEndPoint = AWSEndpoint(urlString: "wss://a1aasfrtim0rdu-ats.iot.us-east-2.amazonaws.com/mqtt")
        let iotDataConfiguration = AWSServiceConfiguration(region: AWSRegionType.USEast2,
                                                           endpoint: iotEndPoint,
                                                           credentialsProvider: AWSMobileClient.sharedInstance())
        
        AWSIoTDataManager.register(with: iotDataConfiguration!, forKey: ioDataManangerName)
        iotDataManager = AWSIoTDataManager(forKey: ioDataManangerName)
    }
    
    private func connectToMqtt() {
        let didConnect = iotDataManager?.connectUsingWebSocket(withClientId: "Fall2019-iosClient",
                                                               cleanSession: true,
                                                               statusCallback: mqttEventCallback)
        print("Connected to MQTT: \(String(describing: didConnect))")
    }
    
    private func mqttEventCallback(_ status: AWSIoTMQTTStatus ) {
        print("mqtt connection status = \(status.rawValue)")
        switch status {
        case .unknown:
            print("mqtt unknown connection status")
        case .connecting:
            print("mqtt connecting to mqtt")
        case .connected:
            print("mqtt connected to MQTT")
            getState()
            subscribeToUpdateDocs()
        case .disconnected:
            print("mqtt disconnected from mqtt")
        case .connectionRefused:
            print("mqtt connection refused from mqtt")
        case .connectionError:
            print(" vconnection error from mqtt")
        case .protocolError:
            print("mqtt protocol errror from mqtt")
        @unknown default:
            print("what happened")
        }
    }
    
    private func getState() {
        subscribeToGetAccepted()
        publishGetMessage()
    }
    
    private func subscribeToGetAccepted() {
        guard let iotDataManager = iotDataManager else {
            return
        }
        
        iotDataManager.subscribe(
            toTopic: "$aws/things/\(deviceName)/shadow/get/accepted",
            qoS: .messageDeliveryAttemptedAtMostOnce, /* Quality of Service */
            messageCallback: {
                (payload) ->Void in
                self.parseGetStateJson(payload)
                let stringValue = NSString(data: payload, encoding: String.Encoding.utf8.rawValue)!
                print("Get Accepted Message received: \(stringValue)")
        })
    }
    
    private func publishGetMessage() {
        guard let iotDataManager = iotDataManager else {
            return
        }
        iotDataManager.publishString("", onTopic: "$aws/things/\(deviceName)/shadow/get", qoS:.messageDeliveryAttemptedAtMostOnce)
    }
    
    private func subscribeToUpdateDocs() {
        guard let iotDataManager = iotDataManager else {
            return
        }
        
        iotDataManager.subscribe(
            toTopic: "$aws/things/\(deviceName)/shadow/update/documents",
            qoS: .messageDeliveryAttemptedAtMostOnce, /* Quality of Service */
            messageCallback: {
                (payload) ->Void in
                self.parseUpdateDocumentsJson(payload)
                let stringValue = NSString(data: payload, encoding: String.Encoding.utf8.rawValue)!
                print("Update docs Message received: \(stringValue)")
        })
    }
    
    private func parseGetStateJson(_ jsonData: Data) {
        guard let jsonDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? Dictionary<String, Any> else {
            return
        }
        
        if let stateData = jsonDict["state"] as? Dictionary<String, Any>, let reported = stateData["reported"] as? Dictionary<String, Any> {
            DispatchQueue.main.async {
                if let temp = reported["temperature"] as? Double {
                    self.temperature = temp
                }
                if let humid = reported["humidity"] as? Double {
                    self.humidity = humid
                }
                if let ledValue = reported["led"] as? Int {
                    self.ledValue = ledValue
                    self.isLedOn = self.ledValue > 0
                }
            }
        }else{
            print("Failed to parse get state JSON dictionary: \(jsonDict)")
        }
    }
    
    private func parseUpdateDocumentsJson(_ jsonData: Data) {
        guard let jsonDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? Dictionary<String, Any> else {
            return
        }
        
        if let currentData = jsonDict["current"] as? Dictionary<String, Any>, let stateData = currentData["state"] as? Dictionary<String, Any>,
            let reported = stateData["reported"] as? Dictionary<String, Any> {
            DispatchQueue.main.async {
                if let temp = reported["temperature"] as? Double {
                    self.temperature = temp
                }
                if let humid = reported["humidity"] as? Double {
                    self.humidity = humid
                }
                if let ledValue = reported["led"] as? Int {
                    self.ledValue = ledValue
                    self.isLedOn = self.ledValue > 0
                }
            }
        }else{
            print("Failed to parse updated docs JSON dictionary: \(jsonDict)")
        }
    }
}
