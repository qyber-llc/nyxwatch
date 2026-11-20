import Foundation
import AppKit

enum SurveillanceVisualState {
    case off
    case waitingBluetooth
    case armed
}

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private var floatingButton: FloatingButtonController?
    private let menu = NSMenu()

    var onToggleSurveillance: (() -> Void)?
    var onToggleManualArm: (() -> Void)?
    var onSelectMode: ((SurveillanceMode) -> Void)?
    var onToggleStrictDisarm: (() -> Void)?
    var onCalibrate: (() -> Void)?
    var onToggleLaunchAtLogin: (() -> Void)?
    var onToggleLanguage: (() -> Void)?
    var onLinkWhatsApp: (() -> Void)?
    var onOpenConfig: (() -> Void)?
    var onCheckPermissions: (() -> Void)?
    var onTestAlert: (() -> Void)?
    var onQuit: (() -> Void)?

    private var currentState: SurveillanceVisualState = .off
    private let statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: "", action: #selector(handleToggle), keyEquivalent: "s")
    private let armMenuItem = NSMenuItem(title: "", action: #selector(handleManualArm), keyEquivalent: "a")
    private let discreetModeItem = NSMenuItem(title: "", action: #selector(handleSelectDiscreet), keyEquivalent: "1")
    private let flagModeItem = NSMenuItem(title: "", action: #selector(handleSelectFlag), keyEquivalent: "2")
    private let strictDisarmItem = NSMenuItem(title: "", action: #selector(handleToggleStrictDisarm), keyEquivalent: "")
    private let calibrateItem = NSMenuItem(title: "", action: #selector(handleCalibrate), keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "", action: #selector(handleToggleLaunchAtLogin), keyEquivalent: "")
    private let languageItem = NSMenuItem(title: "", action: #selector(handleToggleLanguage), keyEquivalent: "l")
    private let linkWAItem = NSMenuItem(title: "", action: #selector(handleLinkWA), keyEquivalent: "w")
    private let configItem = NSMenuItem(title: "", action: #selector(handleConfig), keyEquivalent: ",")
    private let permsItem = NSMenuItem(title: "", action: #selector(handleCheckPermissions), keyEquivalent: "")
    private let testItem = NSMenuItem(title: "", action: #selector(handleTestAlert), keyEquivalent: "t")
    private let quitItem = NSMenuItem(title: "", action: #selector(handleQuit), keyEquivalent: "q")

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: 24)
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusBarClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        buildMenu()
        floatingButton = FloatingButtonController(menu: menu)
        floatingButton?.onToggleSurveillance = { [weak self] in
            self?.onToggleSurveillance?()
        }
        refreshLocalization()
        updateState(.off)
    }

    private func buildMenu() {
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())

        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        armMenuItem.target = self
        menu.addItem(armMenuItem)

        menu.addItem(NSMenuItem.separator())

        discreetModeItem.target = self
        menu.addItem(discreetModeItem)

        flagModeItem.target = self
        menu.addItem(flagModeItem)

        menu.addItem(NSMenuItem.separator())

        strictDisarmItem.target = self
        menu.addItem(strictDisarmItem)


        calibrateItem.target = self
        menu.addItem(calibrateItem)


        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        languageItem.target = self
        menu.addItem(languageItem)

        menu.addItem(NSMenuItem.separator())

        linkWAItem.target = self
        menu.addItem(linkWAItem)

        configItem.target = self
        menu.addItem(configItem)

        permsItem.target = self
        menu.addItem(permsItem)


        testItem.target = self
        menu.addItem(testItem)

        menu.addItem(NSMenuItem.separator())

        quitItem.target = self
        menu.addItem(quitItem)
    }

    func refreshLocalization() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.statusItem.button?.toolTip = L10n.t(
                "NyxWatch — Clic gauche : Activer/Désactiver | Clic droit : Menu",
                "NyxWatch — Left click: Toggle On/Off | Right click: Menu"
            )
            self.discreetModeItem.title = L10n.t(
                "Mode 1 : Alerte + verrouillage",
                "Mode 1: Alert + lock"
            )
            self.flagModeItem.title = L10n.t(
                "Mode 2 : Flag (Flash + Alerte vocale)",
                "Mode 2: Flag (Flash + Voice alert)"
            )
            self.strictDisarmItem.title = L10n.t(
                "Désarmement strict (Anti-Spoofing BT)",
                "Strict Disarm (BT Anti-Spoofing)"
            )
            self.calibrateItem.title = L10n.t(
                "Calibrer la distance à 2 m…",
                "Calibrate distance at 2 m…"
            )
            self.launchAtLoginItem.title = L10n.t(
                "Lancer au démarrage",
                "Launch at login"
            )
            self.languageItem.title = L10n.t(
                "Langue : Français → Switch to English",
                "Language: English → Passer en Français"
            )
            self.linkWAItem.title = L10n.t(
                "Lier WhatsApp...",
                "Link WhatsApp..."
            )
            self.configItem.title = L10n.t("Configurer...", "Settings...")
            self.permsItem.title = L10n.t("État des permissions...", "Permissions check...")
            self.testItem.title = L10n.t("Tester l'alerte maintenant", "Test alert now")
            self.quitItem.title = L10n.t("Quitter NyxWatch", "Quit NyxWatch")
            self.updateState(self.currentState)
        }
    }

    func updateMode(_ mode: SurveillanceMode) {
        DispatchQueue.main.async { [weak self] in
            self?.discreetModeItem.state = (mode == .discreet) ? .on : .off
            self?.flagModeItem.state = (mode == .flag) ? .on : .off
        }
    }

    func updateSecurityOptions(strictDisarm: Bool, launchAtLogin: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            self?.strictDisarmItem.state = strictDisarm ? .on : .off
            self?.launchAtLoginItem.state = launchAtLogin ? .on : .off
        }
    }

    func updateState(_ state: SurveillanceVisualState) {
        currentState = state
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.statusItem.button else { return }

            switch state {
            case .off:
                self.statusMenuItem.title = L10n.t("Statut : Désactivée", "Status: Off")
                self.toggleMenuItem.title = L10n.t("Activer la surveillance", "Enable surveillance")
                self.armMenuItem.title = L10n.t("Armer manuellement (⌘⎋)", "Arm manually (⌘⎋)")
                button.title = ""
            case .waitingBluetooth:
                self.statusMenuItem.title = L10n.t("Statut : Active (Bluetooth)", "Status: Active (Bluetooth)")
                self.toggleMenuItem.title = L10n.t("Désactiver la surveillance", "Disable surveillance")
                self.armMenuItem.title = L10n.t("Armer manuellement (⌘⎋)", "Arm manually (⌘⎋)")
                button.title = ""
            case .armed:
                self.statusMenuItem.title = L10n.t("Statut : ARMÉE", "Status: ARMED")
                self.toggleMenuItem.title = L10n.t("Désactiver la surveillance", "Disable surveillance")
                self.armMenuItem.title = L10n.t("Désarmer", "Disarm")
                button.title = ""
            }

            button.image = NyxWatchBrandIcon.image(size: 19, template: true)
            button.appearsDisabled = state == .off
            self.floatingButton?.updateState(state)

        }
    }

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            onToggleSurveillance?()
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.option) {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            onToggleSurveillance?()
        }
    }

    @objc private func handleToggle() { onToggleSurveillance?() }
    @objc private func handleManualArm() { onToggleManualArm?() }
    @objc private func handleSelectDiscreet() { onSelectMode?(.discreet) }
    @objc private func handleSelectFlag() { onSelectMode?(.flag) }
    @objc private func handleToggleStrictDisarm() { onToggleStrictDisarm?() }
    @objc private func handleCalibrate() { onCalibrate?() }
    @objc private func handleToggleLaunchAtLogin() { onToggleLaunchAtLogin?() }
    @objc private func handleToggleLanguage() { onToggleLanguage?() }
    @objc private func handleLinkWA() { onLinkWhatsApp?() }
    @objc private func handleConfig() { onOpenConfig?() }
    @objc private func handleCheckPermissions() { onCheckPermissions?() }
    @objc private func handleTestAlert() { onTestAlert?() }
    @objc private func handleQuit() { onQuit?() }
}
