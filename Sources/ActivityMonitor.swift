import Foundation
import IOKit
import IOKit.ps
import AppKit

final class ActivityMonitor {
    private var timer: Timer?
    private var lastIdleSeconds: TimeInterval = 0
    private var lastPowerSource: String?
    private var isMonitoring = false
    private var armedAt: Date?
    private let settleSeconds: TimeInterval

    private var usbNotificationPort: IONotificationPortRef?
    private var usbIterator: io_iterator_t = 0

    var onTamperDetected: ((String) -> Void)?

    init(settleSeconds: TimeInterval = 2.0) {
        self.settleSeconds = settleSeconds
        let wsCenter = NSWorkspace.shared.notificationCenter
        wsCenter.addObserver(
            self,
            selector: #selector(handleScreenWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        wsCenter.addObserver(
            self,
            selector: #selector(handleWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        wsCenter.addObserver(
            self,
            selector: #selector(handleVolumeMount(_:)),
            name: NSWorkspace.didMountNotification,
            object: nil
        )
    }

    deinit {
        stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        armedAt = Date()
        lastIdleSeconds = Self.systemIdleSeconds() ?? 0
        lastPowerSource = Self.currentPowerSourceType()

        startUSBMonitoring()

        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.checkActivity()
            self?.checkPowerSource()
        }
    }

    func stop() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
        armedAt = nil
        stopUSBMonitoring()
    }

    private func isPastSettlePeriod() -> Bool {
        guard let armedAt else { return false }
        return Date().timeIntervalSince(armedAt) >= settleSeconds
    }

    @objc private func handleScreenWake() {
        guard isMonitoring, isPastSettlePeriod() else { return }
        onTamperDetected?("Réveil de l'écran détecté")
    }

    @objc private func handleWillSleep() {
        guard isMonitoring, isPastSettlePeriod() else { return }
        onTamperDetected?("Fermeture capot / mise en veille détectée")
    }

    @objc private func handleVolumeMount(_ notification: Notification) {
        guard isMonitoring, isPastSettlePeriod() else { return }
        onTamperDetected?("Montage de volume détecté")
    }

    private func checkPowerSource() {
        guard isMonitoring, isPastSettlePeriod() else { return }
        guard let current = Self.currentPowerSourceType() else { return }
        if let previous = lastPowerSource, previous != current {
            lastPowerSource = current
            if current == kIOPSBatteryPowerValue {
                onTamperDetected?("Débranchement du chargeur secteur détecté")
                return
            }
        }
        lastPowerSource = current
    }

    private func checkActivity() {
        guard isMonitoring, let armedAt else { return }
        guard let currentIdle = Self.systemIdleSeconds() else { return }

        if Date().timeIntervalSince(armedAt) < settleSeconds {
            lastIdleSeconds = currentIdle
            return
        }

        if currentIdle + 0.15 < lastIdleSeconds || (currentIdle < 0.6 && lastIdleSeconds >= 0.6) {
            lastIdleSeconds = currentIdle
            onTamperDetected?("Activité clavier/trackpad/souris détectée")
            return
        }

        lastIdleSeconds = currentIdle
    }

    private func startUSBMonitoring() {
        guard usbNotificationPort == nil else { return }
        let port = IONotificationPortCreate(kIOMainPortDefault)
        usbNotificationPort = port
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)

        let matching = IOServiceMatching("IOUSBHostDevice")
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon else { return }
            let monitor = Unmanaged<ActivityMonitor>.fromOpaque(refcon).takeUnretainedValue()
            var attached = false
            while case let service = IOIteratorNext(iterator), service != 0 {
                IOObjectRelease(service)
                attached = true
            }
            if attached && monitor.isMonitoring && monitor.isPastSettlePeriod() {
                monitor.onTamperDetected?("Branchement périphérique USB détecté")
            }
        }

        let kr = IOServiceAddMatchingNotification(
            port,
            kIOFirstMatchNotification,
            matching,
            callback,
            selfPtr,
            &usbIterator
        )
        if kr == KERN_SUCCESS {
            // Drain initial iterator so only future USB attachments fire
            while case let service = IOIteratorNext(usbIterator), service != 0 {
                IOObjectRelease(service)
            }
        }
    }

    private func stopUSBMonitoring() {
        if usbIterator != 0 {
            IOObjectRelease(usbIterator)
            usbIterator = 0
        }
        if let port = usbNotificationPort {
            IONotificationPortDestroy(port)
            usbNotificationPort = nil
        }
    }

    static func currentPowerSourceType() -> String? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }
        return IOPSGetProvidingPowerSourceType(snapshot)?.takeRetainedValue() as String?
    }

    static func systemIdleSeconds() -> TimeInterval? {
        var iterator: io_iterator_t = 0
        defer {
            if iterator != 0 {
                IOObjectRelease(iterator)
            }
        }

        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem"),
            &iterator
        )
        guard result == KERN_SUCCESS else { return nil }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }

        var properties: Unmanaged<CFMutableDictionary>?
        let propResult = IORegistryEntryCreateCFProperties(
            entry,
            &properties,
            kCFAllocatorDefault,
            0
        )
        guard propResult == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any],
              let idleNano = dict["HIDIdleTime"] as? NSNumber else {
            return nil
        }

        return idleNano.doubleValue / 1_000_000_000.0
    }
}
