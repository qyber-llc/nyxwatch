import Foundation
import CoreBluetooth
import IOBluetooth

final class BluetoothMonitor: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?
    private let config: Config
    private var evaluationTimer: Timer?

    private var lastSeenDate: Date?
    private var rssiSamples: [Int] = []
    private var isCurrentlyNearby: Bool?
    private var awaySince: Date?

    private var discoveredBLE: [UUID: (name: String, rssi: Int)] = [:]
    var onProximityChanged: ((Bool) -> Void)?
    /// "Away" below this averaged signal; changed live by the 2 m calibration.
    var rssiThreshold: Int
    /// The averaged signal of the last evaluation, nil when the device was not heard recently.
    private(set) var lastAverageRSSI: Int?

    init(config: Config) {
        self.config = config
        self.rssiThreshold = config.rssiThreshold
        super.init()
    }

    func startScanAndExit() {
        log("Recherche des appareils Bluetooth appairés (Classic)...")
        if let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice], !paired.isEmpty {
            print("\n--- Appareils Bluetooth appairés (IOBluetooth) ---")
            for dev in paired {
                let name = dev.name ?? "(Sans nom)"
                let addr = dev.addressString ?? "?"
                let conn = dev.isConnected() ? "Connecté" : "Déconnecté"
                let rssi = dev.isConnected() ? "\(dev.rawRSSI()) dBm" : "-"
                print("  • \(name) | Adresse: \(addr) | État: \(conn) | RSSI: \(rssi)")
            }
        } else {
            print("\n--- Aucun appareil Bluetooth appairé ---")
        }

        print("\n--- Scan BLE en cours (6 secondes)... ---")
        centralManager = CBCentralManager(delegate: self, queue: .main)

        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
            guard let self else { exit(0) }
            let sorted = self.discoveredBLE.sorted { $0.value.rssi > $1.value.rssi }
            if sorted.isEmpty {
                print("  Aucun périphérique BLE détecté (vérifiez l'autorisation Bluetooth).")
            } else {
                for (uuid, info) in sorted {
                    print("  • \(info.name) | UUID: \(uuid.uuidString) | RSSI: \(info.rssi) dBm")
                }
            }
            print("\nAstuce : utilisez --device \"Nom\" ou --id \"UUID/Adresse\" pour lancer MacWatch.")
            exit(0)
        }
    }

    func startMonitoring() {
        centralManager = CBCentralManager(delegate: self, queue: .main)
        evaluationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.evaluateProximity()
        }
    }

    func stopMonitoring() {
        evaluationTimer?.invalidate()
        evaluationTimer = nil
        centralManager?.stopScan()
        if pagedDevice?.isConnected() == true { pagedDevice?.closeConnection() }
        pagedDevice = nil
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if config.mode == .scan {
                central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            } else {
                log("Bluetooth actif. Surveillance de proximité démarrée...")
                central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            }
        case .unauthorized:
            log("Erreur : autorisation Bluetooth refusée. Activez Bluetooth pour MacWatch dans Réglages Système.")
        case .poweredOff:
            log("Avertissement : le Bluetooth du Mac est désactivé.")
        default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let rssiValue = RSSI.intValue
        guard rssiValue != 127 && rssiValue < 0 else { return }

        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = peripheral.name ?? advName ?? "(Inconnu)"

        if config.mode == .scan {
            discoveredBLE[peripheral.identifier] = (name: name, rssi: rssiValue)
            return
        }

        if matchesTarget(name: name, identifier: peripheral.identifier.uuidString) {
            recordRSSI(rssiValue)
        }
    }

    // MARK: - Matching & Evaluation

    /// "z fold 6" finds "Alex's Z Fold6", "aa-bb-cc-…" finds "AA:BB:CC:…": spaces, case and separators don't count.
    private static func normalized(_ text: String?) -> String {
        (text ?? "").lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func matchesTarget(name: String?, identifier: String?) -> Bool {
        let targetID = Self.normalized(config.deviceIdentifier)
        if !targetID.isEmpty, Self.normalized(identifier) == targetID {
            return true
        }
        let targetName = Self.normalized(config.deviceName)
        if !targetName.isEmpty, Self.normalized(name).contains(targetName) {
            return true
        }
        return false
    }

    private func recordRSSI(_ rssi: Int) {
        lastSeenDate = Date()
        rssiSamples.append(rssi)
        if rssiSamples.count > 5 {
            rssiSamples.removeFirst()
        }
    }

    private func checkClassicBluetoothNearby() -> Bool? {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return nil
        }
        for dev in paired {
            if matchesTarget(name: dev.name, identifier: dev.addressString) {
                // A paired phone is judged by presence, not distance: its classic signal is held flat by power
                // control and its BLE adverts don't track distance (Z Fold6: -77 dBm beside the Mac, -69..-87 at
                // 5 m). Present = link up or a page answered in the last 20 s; out of range (~10 m) pages fail.
                if dev.isConnected() { lastPresentAt = Date() } else { pageIfDue(dev) }
                return lastPresentAt.map { Date().timeIntervalSince($0) <= 20 } ?? false
            }
        }
        return nil
    }

    private var lastPageAt: Date?
    private var pageInFlight = false
    private var pagedDevice: IOBluetoothDevice?
    private var lastPresentAt: Date?

    /// An Android phone stays paired but not connected, so it is never heard on its own: open a link to it
    /// every 8 s (asynchronously) so its signal can be read; out of range, the page simply fails.
    private func pageIfDue(_ device: IOBluetoothDevice) {
        let now = Date()
        guard !pageInFlight, now.timeIntervalSince(lastPageAt ?? .distantPast) >= 8 else { return }
        lastPageAt = now
        pageInFlight = true
        pagedDevice = device
        if device.openConnection(self) != kIOReturnSuccess { pageInFlight = false }
    }

    @objc func connectionComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        pageInFlight = false
        if status == kIOReturnSuccess { lastPresentAt = Date() }
    }

    private func evaluateProximity() {
        let classicNearby = checkClassicBluetoothNearby()
        let now = Date()

        let avgRSSI: Int? = rssiSamples.isEmpty ? nil : (rssiSamples.reduce(0, +) / rssiSamples.count)
        let bleRecent = lastSeenDate.map { now.timeIntervalSince($0) <= 4.0 } ?? false
        lastAverageRSSI = bleRecent ? avgRSSI : nil

        let nearbyNow: Bool
        if let classicNearby {
            nearbyNow = classicNearby
        } else if bleRecent, let avgRSSI {
            nearbyNow = avgRSSI >= rssiThreshold
        } else {
            nearbyNow = false
        }

        if config.verbose {
            let rssiText = avgRSSI.map { "\($0) dBm" } ?? "aucun signal"
            log("BT -> proche: \(nearbyNow) | RSSI moyen: \(rssiText) (seuil: \(rssiThreshold) dBm)")
        }

        if nearbyNow {
            awaySince = nil
            if isCurrentlyNearby != true {
                isCurrentlyNearby = true
                onProximityChanged?(true)
            }
        } else {
            if awaySince == nil {
                awaySince = now
            }
            let awayDuration = now.timeIntervalSince(awaySince!)
            // A phone never heard since monitoring started is not "away": it may just be undetectable.
            if awayDuration >= config.awayDelaySeconds {
                if isCurrentlyNearby == true {
                    isCurrentlyNearby = false
                    onProximityChanged?(false)
                }
            }
        }
    }
}
