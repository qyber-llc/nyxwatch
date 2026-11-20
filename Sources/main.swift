import Foundation
import AppKit
import Carbon.HIToolbox

final class MacWatchController {
    private var config: Config
    private let powerManager = PowerManager()
    private var activityMonitor: ActivityMonitor
    private var bluetoothMonitor: BluetoothMonitor
    private var statusBar: StatusBarController?

    private var isSurveillanceEnabled = false
    private var isArmed = false
    private var lastAlertDate: Date?
    private var hotKeyRef: EventHotKeyRef?

    init(config: Config) {
        self.config = config
        self.activityMonitor = ActivityMonitor(settleSeconds: config.armSettleSeconds)
        self.bluetoothMonitor = BluetoothMonitor(config: config)
    }

    func run() {
        switch config.mode {
        case .scan:
            bluetoothMonitor.startScanAndExit()
            RunLoop.main.run()

        case .testAlert:
            log("Mode TEST : envoi de notification (sans verrouillage)...")
            triggerAlert(reason: "Test manuel NyxWatch", lock: false) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    exit(0)
                }
            }
            RunLoop.main.run()

        case .monitor:
            wireMonitors()
            NSApp.run()
        }
    }

    func onAppFinishedLaunching() {
        setupStatusBar()
        registerGlobalHotKey()
        // Unlocking the Mac proves the owner is back: disarm, or the touch that unlocks would trip a new alert.
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.isArmed else { return }
            log("🔓 Mac déverrouillé par le propriétaire : désarmement.")
            self.disarm()
        }
        Notifier.startRetryLoop()

        let launchedWithTarget = CommandLine.arguments.contains("--id")
            || CommandLine.arguments.contains("-i")
            || CommandLine.arguments.contains("--device")
            || CommandLine.arguments.contains("-d")
            || CommandLine.arguments.contains("--arm-now")

        if launchedWithTarget {
            SettingsStore.shared.save(from: config)
            enableSurveillance()
        } else {
            log("MacWatch prêt dans la barre des menus et bouton flottant affiché.")
        }
    }

    private func registerGlobalHotKey() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if hotKeyID.id == 1 {
                    let controller = Unmanaged<MacWatchController>.fromOpaque(userData).takeUnretainedValue()
                    DispatchQueue.main.async {
                        if !controller.isArmed {
                            controller.toggleManualArm()
                        }
                    }
                }
                return noErr
            },
            1,
            &eventSpec,
            selfPtr,
            nil
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x4E595857), id: 1) // 'NYXW'
        let status = RegisterEventHotKey(
            UInt32(kVK_Escape),
            UInt32(cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr {
            log("Raccourci global Cmd+Echap enregistré pour armer NyxWatch.")
        } else {
            log("Avertissement : impossible d'enregistrer Cmd+Echap (code \(status)).")
        }
    }

    func handleReopen() {
        showConfigDialog()
    }

    private func setupStatusBar() {
        let bar = StatusBarController()
        bar.onToggleSurveillance = { [weak self] in
            self?.toggleSurveillance()
        }
        bar.onToggleManualArm = { [weak self] in
            self?.toggleManualArm()
        }
        bar.onSelectMode = { [weak self] mode in
            guard let self else { return }
            self.config.surveillanceMode = mode
            SettingsStore.shared.save(from: self.config)
            self.statusBar?.updateMode(mode)
            log("Mode sélectionné : \(mode == .discreet ? "Alerte + verrouillage" : "Flag (Flash + Alerte vocale)")")
        }
        bar.onToggleStrictDisarm = { [weak self] in
            guard let self else { return }
            self.config.strictDisarm.toggle()
            SettingsStore.shared.save(from: self.config)
            self.statusBar?.updateSecurityOptions(strictDisarm: self.config.strictDisarm)
            log("Désarmement strict : \(self.config.strictDisarm ? "ACTIVÉ" : "DÉSACTIVÉ")")
        }
        bar.onCalibrate = { [weak self] in
            self?.calibrateAwayDistance()
        }
        bar.onToggleLaunchAtLogin = { [weak self] in
            self?.toggleLaunchAtLogin()
        }
        bar.onToggleLanguage = { [weak self] in
            L10n.current = (L10n.current == .fr) ? .en : .fr
            UserDefaults.standard.set(L10n.current.rawValue, forKey: "macwatch.language")
            self?.statusBar?.refreshLocalization()
            log("Language switched to: \(L10n.current.rawValue.uppercased())")
        }
        bar.updateMode(config.surveillanceMode)
        bar.updateSecurityOptions(
            strictDisarm: config.strictDisarm,
            launchAtLogin: isLaunchAtLoginEnabled()
        )
        bar.onLinkWhatsApp = { [weak self] in
            self?.launchWhatsAppLoginInTerminal()
        }
        bar.onOpenConfig = { [weak self] in
            self?.showConfigDialog()
        }
        bar.onCheckPermissions = { [weak self] in
            self?.showPermissionsCheck()
        }
        bar.onTestAlert = { [weak self] in
            self?.triggerAlert(reason: "Test manuel depuis le menu", lock: false)
        }
        bar.onQuit = {
            log("Arrêt de MacWatch.")
            NSApp.terminate(nil)
        }
        self.statusBar = bar
    }

    private func wireMonitors() {
        activityMonitor.onTamperDetected = { [weak self] reason in
            self?.handleTamper(reason: reason)
        }

        bluetoothMonitor.onProximityChanged = { [weak self] nearby in
            guard let self, self.isSurveillanceEnabled else { return }
            if nearby {
                if self.config.strictDisarm && self.isArmed {
                    log("Appareil Bluetooth détecté, mais désarmement strict actif (cliquez sur Désarmer).")
                } else {
                    self.disarm()
                }
            } else {
                self.arm(reason: "Appareil Bluetooth éloigné")
            }
        }
    }

    private func toggleSurveillance() {
        if isSurveillanceEnabled {
            disableSurveillance()
        } else {
            enableSurveillance()
        }
    }

    private func requestRequiredPermissions() {
        if !Notifier.isLocalBridgeLinked() && config.whatsappAutoSend && !AXIsProcessTrusted() {
            let promptKey = "macwatch.didPromptAccessibility"
            if !UserDefaults.standard.bool(forKey: promptKey) {
                UserDefaults.standard.set(true, forKey: promptKey)
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
            }
        }
    }

    private func enableSurveillance() {
        guard !isSurveillanceEnabled else { return }
        requestRequiredPermissions()
        isSurveillanceEnabled = true
        powerManager.preventSleep()

        if config.armImmediately || (config.deviceName == nil && config.deviceIdentifier == nil) {
            arm(reason: "Armement manuel (sans Bluetooth)")
        } else {
            let targetDesc = config.deviceName ?? config.deviceIdentifier ?? "appareil"
            log("Surveillance activée. En attente de proximité pour : \(targetDesc)")
            statusBar?.updateState(.waitingBluetooth)
            bluetoothMonitor.startMonitoring()
        }
    }

    private func disableSurveillance() {
        guard isSurveillanceEnabled else { return }
        isSurveillanceEnabled = false
        bluetoothMonitor.stopMonitoring()
        disarm()
        powerManager.allowSleep()
        statusBar?.updateState(.off)
        log("⏸️  Surveillance désactivée.")
    }

    private func toggleManualArm() {
        if isArmed {
            disarm()
            if !isSurveillanceEnabled {
                statusBar?.updateState(.off)
            }
        } else {
            requestRequiredPermissions()
            if !isSurveillanceEnabled {
                isSurveillanceEnabled = true
                powerManager.preventSleep()
            }
            arm(reason: "Armement manuel")
        }
    }

    private var isCalibrating = false

    /// Listens to the phone for 10 s where the owner put it (2 m away): that mean signal becomes the away threshold.
    private func calibrateAwayDistance() {
        guard !isCalibrating else { return }
        guard isSurveillanceEnabled, config.deviceName != nil || config.deviceIdentifier != nil else {
            showInfo(L10n.t("Activez d'abord la surveillance avec votre téléphone (nom ou UUID).",
                            "Turn surveillance on with your phone (name or UUID) first."))
            return
        }
        showInfo(L10n.t("Posez votre téléphone à 2 m du Mac, puis cliquez OK et laissez-le 10 s.",
                        "Put your phone 2 m from the Mac, click OK and leave it there for 10 s."))
        isCalibrating = true
        var readings: [Int] = []
        var ticks = 0
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if let rssi = self.bluetoothMonitor.lastAverageRSSI { readings.append(rssi) }
            ticks += 1
            guard ticks >= 10 else { return }
            timer.invalidate()
            self.isCalibrating = false
            guard readings.count >= 3 else {
                self.showInfo(L10n.t("Calibrage raté : téléphone non entendu. Vérifiez son nom et le Bluetooth.",
                                     "Calibration failed: phone not heard. Check its name and Bluetooth."))
                return
            }
            let threshold = Int((Double(readings.reduce(0, +)) / Double(readings.count)).rounded())
            self.config.rssiThreshold = threshold
            self.bluetoothMonitor.rssiThreshold = threshold
            SettingsStore.shared.save(from: self.config)
            log("📏 Calibré à 2 m : éloigné sous \(threshold) dBm.")
            self.showInfo(L10n.t("Calibré : au-delà de 2 m (sous \(threshold) dBm), NyxWatch s'arme.",
                                 "Calibrated: beyond 2 m (below \(threshold) dBm), NyxWatch arms."))
        }
    }

    private func launchAgentPlistURL() -> URL {
        let dir = NSString(string: "~/Library/LaunchAgents").expandingTildeInPath
        return URL(fileURLWithPath: dir).appendingPathComponent("com.nyxwatch.app.plist")
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentPlistURL().path)
    }

    private func toggleLaunchAtLogin() {
        let plistURL = launchAgentPlistURL()
        if isLaunchAtLoginEnabled() {
            try? FileManager.default.removeItem(at: plistURL)
            log("Lancement au démarrage désactivé.")
        } else {
            let appExec = Bundle.main.executablePath
                ?? NSString(string: "~/Applications/NyxWatch.app/Contents/MacOS/NyxWatch").expandingTildeInPath
            let plist: [String: Any] = [
                "Label": "com.nyxwatch.app",
                "ProgramArguments": [appExec],
                "RunAtLoad": true,
                "KeepAlive": false
            ]
            try? FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                try? data.write(to: plistURL)
                log("Lancement au démarrage activé.")
            }
        }
        statusBar?.updateSecurityOptions(
            strictDisarm: config.strictDisarm,
            launchAtLogin: isLaunchAtLoginEnabled()
        )
    }

    private func showPermissionsCheck() {
        let mark: (Bool) -> String = { $0 ? "✅" : "❌" }
        showInfo("""
        \(mark(Notifier.isLocalBridgeLinked())) \(L10n.t("Bridge WhatsApp local", "Local WhatsApp bridge"))
        \(L10n.t("Aucune caméra, aucun microphone, aucune capture d’écran ni lecture des frappes.",
                  "No camera, microphone, screen capture or keystroke collection."))
        """)
    }

    private func showInfo(_ text: String) {
        let alert = NSAlert()
        alert.messageText = "NyxWatch"
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func arm(reason: String) {
        guard !isArmed else { return }
        isArmed = true
        statusBar?.updateState(.armed)
        log("🛡️  MODE SURVEILLANCE ACTIVÉ (\(reason)).")
        activityMonitor.start()
    }

    private func disarm() {
        guard isArmed else {
            if isSurveillanceEnabled {
                statusBar?.updateState(.waitingBluetooth)
            }
            return
        }
        isArmed = false
        activityMonitor.stop()
        Notifier.restoreWallpaperIfNeeded()
        statusBar?.updateState(isSurveillanceEnabled ? .waitingBluetooth : .off)
        log("🔓 Mode surveillance désarmé.")
    }

    private func handleTamper(reason: String) {
        guard isArmed else { return }
        let now = Date()
        if let lastAlertDate, now.timeIntervalSince(lastAlertDate) < config.cooldownSeconds {
            return
        }

        lastAlertDate = now
        log("🚨 INTRUSION DÉTECTÉE : \(reason)")
        triggerAlert(reason: reason)
    }

    private func triggerAlert(reason: String, lock: Bool = true, completion: (() -> Void)? = nil) {
        // Lock immediately; delivery failures must never delay protection.
        if lock {
            Notifier.lockScreen()
            if config.surveillanceMode == .flag {
                Notifier.flashScreen()
                Notifier.speakFlagAlertEnglish()
            }
        }
        // Network and Messages delivery may block, so keep the menu and unlock handling responsive.
        let alertConfig = config
        DispatchQueue.global(qos: .utility).async {
            Notifier.sendAlerts(config: alertConfig, reason: reason)
            DispatchQueue.main.async { completion?() }
        }
    }

    private func launchWhatsAppLoginInTerminal() {
        let nodePath = Notifier.findNodeBinary() ?? "node"
        let scriptPath = Notifier.bridgeScriptPath()
        let cmd = "\"\(nodePath)\" \"\(scriptPath)\" --login"
        let escapedCmd = cmd.replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(escapedCmd)"
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        try? process.run()
    }

    private func showConfigDialog() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = L10n.t("Configuration NyxWatch", "NyxWatch Settings")
        alert.informativeText = L10n.t(
            "Renseignez votre appareil Bluetooth et votre numéro WhatsApp.",
            "Enter your Bluetooth device and WhatsApp number."
        )
        alert.addButton(withTitle: L10n.t("Enregistrer", "Save"))
        alert.addButton(withTitle: L10n.t("Annuler", "Cancel"))

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 170))

        let idLabel = NSTextField(labelWithString: L10n.t("Adresse MAC ou UUID Bluetooth :", "Bluetooth MAC Address or UUID:"))
        idLabel.frame = NSRect(x: 0, y: 146, width: 340, height: 18)
        let idField = NSTextField(frame: NSRect(x: 0, y: 120, width: 340, height: 22))
        idField.placeholderString = "ex: aa-bb-cc-dd-ee-ff"
        idField.stringValue = config.deviceIdentifier ?? ""

        let nameLabel = NSTextField(labelWithString: L10n.t("Ou nom Bluetooth (optionnel) :", "Or Bluetooth name (optional):"))
        nameLabel.frame = NSRect(x: 0, y: 96, width: 340, height: 18)
        let nameField = NSTextField(frame: NSRect(x: 0, y: 70, width: 340, height: 22))
        nameField.placeholderString = "ex: Z Fold6"
        nameField.stringValue = config.deviceName ?? ""

        let waLabel = NSTextField(labelWithString: L10n.t("Numéro WhatsApp (format international) :", "WhatsApp number (international format):"))
        waLabel.frame = NSRect(x: 0, y: 46, width: 340, height: 18)
        let waField = NSTextField(frame: NSRect(x: 0, y: 20, width: 200, height: 22))
        waField.placeholderString = "ex: +33612345678"
        waField.stringValue = config.whatsappTarget ?? ""

        let autoSendCheck = NSButton(checkboxWithTitle: L10n.t("Auto-envoi Desktop", "Desktop auto-send"), target: nil, action: nil)
        autoSendCheck.frame = NSRect(x: 208, y: 21, width: 132, height: 20)
        autoSendCheck.state = config.whatsappAutoSend ? .on : .off

        let cmbField = NSTextField(frame: NSRect(x: 0, y: -6, width: 340, height: 22))
        cmbField.placeholderString = L10n.t("Clé CallMeBot (optionnel)", "CallMeBot key (optional)")
        cmbField.stringValue = config.callMeBotKey ?? ""

        container.frame = NSRect(x: 0, y: 0, width: 340, height: 175)
        container.addSubview(idLabel)
        container.addSubview(idField)
        container.addSubview(nameLabel)
        container.addSubview(nameField)
        container.addSubview(waLabel)
        container.addSubview(waField)
        container.addSubview(autoSendCheck)

        let tgTokenLabel = NSTextField(labelWithString: L10n.t("Telegram Bot Token (optionnel) :", "Telegram Bot Token (optional):"))
        let tgTokenField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 22))
        tgTokenField.placeholderString = "123456:ABC..."
        tgTokenField.stringValue = config.telegramBotToken ?? ""

        let tgChatField = NSTextField(frame: NSRect(x: 208, y: 0, width: 132, height: 22))
        tgChatField.placeholderString = "Chat ID"
        tgChatField.stringValue = config.telegramChatId ?? ""

        let studioLabel = NSTextField(labelWithString: L10n.t("Mac Studio URL (alertes) :", "Mac Studio URL (alerts):"))
        let studioField = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 22))
        studioField.placeholderString = "http://mac-studio.local:8787/alert"
        studioField.stringValue = config.macStudioEndpoint ?? ""

        container.frame = NSRect(x: 0, y: 0, width: 340, height: 310)
        idLabel.frame.origin.y = 286
        idField.frame.origin.y = 260
        nameLabel.frame.origin.y = 236
        nameField.frame.origin.y = 210
        waLabel.frame.origin.y = 186
        waField.frame.origin.y = 160
        autoSendCheck.frame.origin.y = 161
        let cmbLabel = NSTextField(labelWithString: L10n.t("Clé CallMeBot (optionnel) :", "CallMeBot key (optional):"))
        cmbLabel.frame = NSRect(x: 0, y: 134, width: 340, height: 18)
        cmbField.frame = NSRect(x: 0, y: 108, width: 340, height: 22)
        tgTokenLabel.frame = NSRect(x: 0, y: 84, width: 340, height: 18)
        tgTokenField.frame.origin.y = 58
        tgChatField.frame.origin.y = 58
        studioLabel.frame = NSRect(x: 0, y: 34, width: 340, height: 18)
        studioField.frame.origin.y = 8

        container.addSubview(cmbLabel)
        container.addSubview(cmbField)
        container.addSubview(tgTokenLabel)
        container.addSubview(tgTokenField)
        container.addSubview(tgChatField)
        container.addSubview(studioLabel)
        container.addSubview(studioField)

        alert.accessoryView = container

        if alert.runModal() == .alertFirstButtonReturn {
            let newId = idField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let newName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let newWa = waField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let newCmb = cmbField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let newTgToken = tgTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let newTgChat = tgChatField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let newStudio = studioField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

            config.deviceIdentifier = newId.isEmpty ? nil : newId
            config.deviceName = newName.isEmpty ? nil : newName
            config.whatsappTarget = newWa.isEmpty ? nil : newWa
            config.whatsappAutoSend = (autoSendCheck.state == .on)
            config.callMeBotKey = newCmb.isEmpty ? nil : newCmb
            config.telegramBotToken = newTgToken.isEmpty ? nil : newTgToken
            config.telegramChatId = newTgChat.isEmpty ? nil : newTgChat
            config.macStudioEndpoint = newStudio.isEmpty ? nil : newStudio

            SettingsStore.shared.save(from: config)

            // Recrée le BluetoothMonitor avec la nouvelle config
            let wasEnabled = isSurveillanceEnabled
            if wasEnabled { disableSurveillance() }
            bluetoothMonitor = BluetoothMonitor(config: config)
            wireMonitors()
            if wasEnabled { enableSurveillance() }
            log("Configuration enregistrée.")
        }
    }
}

final class MacWatchAppDelegate: NSObject, NSApplicationDelegate {
    weak var controller: MacWatchController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller?.onAppFinishedLaunching()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.handleReopen()
        return true
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

signal(SIGINT) { _ in
    log("Arrêt de MacWatch.")
    exit(0)
}
signal(SIGTERM) { _ in
    log("Arrêt de MacWatch.")
    exit(0)
}

var config = Config.parse()
SettingsStore.shared.loadInto(&config)
let controller = MacWatchController(config: config)
let appDelegate = MacWatchAppDelegate()
appDelegate.controller = controller
app.delegate = appDelegate
controller.run()
