//
//  M365Info.swift
//  ble-ios
//
//  Created by Michał Jach on 11/07/2019.
//  Copyright © 2019 Michał Jach. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol M365DataDelegate {
    func didUpdateValues(values: [String:String])
}

protocol M365DevicesDelegate {
    func didDiscoverDevice(peripheral: CBPeripheral)
    func didConnect(peripheral: CBPeripheral)
}

protocol M365StateDelegate {
    func didChangeState(state: CBManagerState)
}

class M365Info: NSObject {
    public var centralManager: CBCentralManager!
    public var dataDelegate: M365DataDelegate?
    public var devicesDelegate: M365DevicesDelegate?
    public var stateDelegate: M365StateDelegate?
    public var devices: [CBPeripheral] = []
    public var connectedDevice: CBPeripheral?
    
    var values: [String: String] = [:]
    
    private let writeCharacterisitc = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let readCharacterisitc = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    private var speedTimer: Timer?
    
    var payloads: [[UInt8]] = [
        [0x55, 0xAA, 0x03, 0x20, 0x01, 0x10, 0x0e, 0xbd, 0xFF], // Serial Number
        [0x55, 0xaa, 0x03, 0x20, 0x01, 0x1A, 0x02, 0xbf, 0xff], // Firmware Version
        [0x55, 0xaa, 0x03, 0x20, 0x01, 0x22, 0x02, 0xb7, 0xff], // Battery Level
        [0x55, 0xaa, 0x03, 0x20, 0x01, 0x3e, 0x02, 0x9b, 0xff], // Body Temperature
        [0x55, 0xaa, 0x03, 0x20, 0x01, 0x29, 0x04, 0xae, 0xff], // Total mileage
        [0x55, 0xaa, 0x03, 0x20, 0x01, 0x47, 0x02, 0x92, 0xff], // Voltage
        [0x55, 0xaa, 0x03, 0x20, 0x01, 0xb5, 0x02, 0x24, 0xff], // Current speed
    ]
    
    required override init() {
        super.init()

        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func discover() {
        centralManager.scanForPeripherals(withServices: nil)
    }
    
    func connect(device: CBPeripheral) {
        centralManager.stopScan()
        centralManager.connect(device, options: nil)
    }
    
    func disconnect() {
        if let connectedDevice = connectedDevice {
            speedTimer?.invalidate()
            centralManager.cancelPeripheralConnection(connectedDevice)
        }
    }
}

extension M365Info: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateDelegate?.didChangeState(state: central.state)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if devices.filter({ $0.name == peripheral.name }).count == 0 {
            devices.append(peripheral)
            devicesDelegate?.didDiscoverDevice(peripheral: peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        connectedDevice = peripheral
        devicesDelegate?.didConnect(peripheral: peripheral)
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
            if characteristic.uuid == self.writeCharacterisitc {
                for payload in payloads {
                    if payload == payloads[6] {
                        self.speedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { timer in
                            peripheral.writeValue(Data(payload), for: characteristic, type: .withoutResponse)
                        })
                        
                        self.speedTimer?.fire()
                    } else {
                        peripheral.writeValue(Data(payload), for: characteristic, type: .withoutResponse)
                        sleep(1)
                    }
                }
            }
            if characteristic.uuid == self.readCharacterisitc {
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        if characteristic.value!.count > 6 {
            let cmd = characteristic.value![5..<6].map { String(format: "%02hhX", $0) }[0]
            let value = characteristic.value![6..<characteristic.value!.count-2]
            switch cmd {
                case "1A":
                    values["Firmware Version"] = versionSerializer(bytes: value)
                    break
                case "10":
                    values["Serial Number"] = asciiSerializer(bytes: value)
                    break
                case "22":
                    values["Battery Level"] = numberSerializer(bytes: value) + "%"
                    break
                case "3E":
                    values["Body Temperature"] = numberSerializer(bytes: value, factor: 10) + "°C"
                    break
                case "29":
                    values["Total Mileage"] = distanceSerializer(bytes: value) + "km"
                    break
                case "47":
                    values["Voltage"] = numberSerializer(bytes: value, format: "%.2f", factor: 100) + "V"
                    break
                case "B5":
                    values["Current Speed"] = numberSerializer(bytes: value, format: "%.2f", factor: 1000) + "km/h"
                    break
                case "74":
                    values["Speed Limit"] = numberSerializer(bytes: value, format: "%.2f", factor: 1000) + "km/h"
                    break
                case "72":
                    values["Limit Enabled"] = numberSerializer(bytes: value)
                    break
                default:
                    print("unrecognized value")
                    break
            }
            dataDelegate?.didUpdateValues(values: values)
        }
    }
    
    func swapBytes(data: Data) -> Data {
        var mdata = data
        let count = data.count / MemoryLayout<UInt16>.size
        mdata.withUnsafeMutableBytes { (i16ptr: UnsafeMutablePointer<UInt16>) in
            for i in 0..<count {
                i16ptr[i] = i16ptr[i].byteSwapped
            }
        }
        return mdata
    }
    
    func distanceSerializer(bytes: Data) -> String {
        let bytesArray = swapBytes(data: bytes).map { String(format: "%02hhX", $0) }
        let major = Int(bytesArray[0] + bytesArray[1], radix: 16)!
        let minor = Int(bytesArray[2] + bytesArray[3], radix: 16)!
        return String(format: "%.2f", Double(major + minor * 65536)/1000)
    }
    
    func versionSerializer(bytes: Data) -> String {
        let bytesArray = bytes.map { String(format: "%02hhX", $0) }
        let majorVersion = Int(bytesArray[1])!
        let minorVersion = Array(String(Int(bytesArray[0])!))[0]
        let subVersion = Array(String(Int(bytesArray[0])!))[1]
        return String(majorVersion) + "." + String(minorVersion) + "." + String(subVersion)
    }
    
    func asciiSerializer(bytes: Data) -> String {
        return String(data: bytes, encoding: String.Encoding.ascii)!
    }
    
    func numberSerializer(bytes: Data, format: String = "%.0f", factor: Int = 1) -> String {
        let hexString = swapBytes(data: bytes).map { String(format: "%02hhX", $0) }.joined()
        return String(format: format, Double(Int(hexString, radix: 16)!/factor))
    }
}
