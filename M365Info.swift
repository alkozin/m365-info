//
//  M365Info.swift
//  ble-ios
//
//  Created by Michał Jach on 11/07/2019.
//  Copyright © 2019 Michał Jach. All rights reserved.
//

import Foundation
import CoreBluetooth

class M365Info: NSObject {
    public var centralManager: CBCentralManager!
    fileprivate let data = NSMutableData()
    fileprivate var discoveredPeripheral: CBPeripheral?
    
    required override init() {
        super.init()

        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
}

extension M365Info: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
        case .poweredOn:
            print("central.state is .poweredOn")
            centralManager.scanForPeripherals(withServices: nil)
        @unknown default:
            print("error")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral.name)
        if peripheral.name == "MIScooter1613" || peripheral.name == "MISc" {
            discoveredPeripheral = peripheral
            centralManager.stopScan()
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Peripheral Connected")
        peripheral.delegate = self
        peripheral.discoverServices([])
    }
}

extension M365Info: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics([], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") {
                let data:[UInt8] = [0x55, 0xAA, 0x03, 0x20, 0x01, 0x10, 0x0E, 0xBD, 0xFF]
                let writeData = Data(data)
                peripheral.writeValue(writeData, for: characteristic, type: .withResponse)
            }
            if characteristic.uuid == CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") {
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Message sent")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        let asciiString = String(data: characteristic.value!, encoding: String.Encoding.ascii)
        //        print(asciiString)
        //        print(characteristic.value)
        
        let array = [UInt8](characteristic.value!)
        
        if (array.count > 3) {
            if let string = String(bytes: array.suffix(from: 2), encoding: .ascii) {
                print(string)
            } else {
                print("not a valid UTF-8 sequence")
            }
        }
    }
    
}
