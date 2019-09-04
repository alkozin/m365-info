# ```m365 Info```
Get info about your Xiaomi Mijia 365 Scooter via BLE (Bluetooth Low Energy) using Swift and Core Bluetooth Framework.

### Requirements
- macOS 10.10+
- Xcode or Xcode Command Tools
- BLE compatible device (Bluetooth 5.0)

### Usage
```
Drag and drop M365Info.swift class into your project. Initialize like let m365 = M365Info().
```

### API

## .discover()
Start scanning for devices. Use `M365DevicesDelegate` delegate methods:
```
didDiscoverDevice(peripheral: CBPeripheral)
didConnect(peripheral: CBPeripheral)
```

## .connect(device: CBPeripheral)
Connect to given device and get all data. After connection is being made  Use `M365DevicesDelegate` delegate methods:
```
didDiscoverDevice(peripheral: CBPeripheral)
didConnect(peripheral: CBPeripheral)
```

## .disconnect()
Disconnect from currently connected device. Use `M365DevicesDelegate` delegate methods:
```
didDiscoverDevice(peripheral: CBPeripheral)
didConnect(peripheral: CBPeripheral)
```

## .values
List of key and value pairs with scooter data obtained after connection. You can simply do `let sn = values["Serial Number"]`

| Array Keys       |
|------------------|
| Firmware Version |
| Serial Number    |
| Battery Level    |
| Body Temperature |
| Total Mileage    |
| Voltage          |
| Current Speed    |
