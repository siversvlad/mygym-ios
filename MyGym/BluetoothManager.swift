import Foundation
import CoreBluetooth

final class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var wantsScan = false
    private let heartService = CBUUID(string: "180D")
    private let heartCharacteristic = CBUUID(string: "2A37")
    private let emit: ([String: Any]) -> Void

    init(emit: @escaping ([String: Any]) -> Void) {
        self.emit = emit
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }
    func scan() {
        wantsScan = true
        guard central.state == .poweredOn else {
            emit(["type":"error", "message":"Bluetooth недоступен. Включите Bluetooth и разрешите доступ MyGym."])
            return
        }
        central.scanForPeripherals(withServices: [heartService], options: nil)
    }
    func disconnect() {
        wantsScan = false
        central.stopScan()
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        emit(["type":"disconnected"])
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn && wantsScan { scan() }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        emit(["type":"connected", "name":peripheral.name ?? "BLE Heart Rate"])
        peripheral.discoverServices([heartService])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        emit(["type":"error", "message":error?.localizedDescription ?? "Не удалось подключиться"])
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        emit(["type":"disconnected"])
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == heartService {
            peripheral.discoverCharacteristics([heartCharacteristic], for: service)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for char in chars where char.uuid == heartCharacteristic { peripheral.setNotifyValue(true, for: char) }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == heartCharacteristic, let data = characteristic.value,
              data.count >= 2 else { return }
        let bytes = [UInt8](data)
        let bpm: Int
        if bytes[0] & 1 == 1 {
            guard bytes.count >= 3 else { return }
            bpm = Int(bytes[1]) | (Int(bytes[2]) << 8)
        } else { bpm = Int(bytes[1]) }
        if (20...250).contains(bpm) { emit(["type":"pulse", "bpm":bpm]) }
    }
}
