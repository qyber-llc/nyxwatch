import Foundation
import AppKit

final class Notifier {
    static func flashScreen() {
        DispatchQueue.main.async {
            var windows: [NSWindow] = []
            for screen in NSScreen.screens {
                let win = NSWindow(
                    contentRect: screen.frame,
                    styleMask: .borderless,
                    backing: .buffered,
                    defer: false
                )
                win.level = .screenSaver
                win.backgroundColor = .white
                win.isOpaque = true
                win.ignoresMouseEvents = true
                win.orderFrontRegardless()
                windows.append(win)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                for win in windows {
                    win.orderOut(nil)
                }
            }
        }
    }

    /// Each display's own wallpaper, keyed by its display ID, so a multi-screen setup gets each one back.
    private static let savedWallpapersKey = "macwatch.savedWallpapers"

    private static func displayID(_ screen: NSScreen) -> String? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue
    }

    static func restoreWallpaperIfNeeded() {
        // Older builds saved one path for every screen: keep it as the fallback.
        let legacy = UserDefaults.standard.string(forKey: "macwatch.savedWallpaperPath")
        let saved = UserDefaults.standard.dictionary(forKey: savedWallpapersKey) as? [String: String] ?? [:]
        guard !saved.isEmpty || legacy != nil else { return }
        DispatchQueue.main.async {
            for screen in NSScreen.screens {
                guard let path = displayID(screen).flatMap({ saved[$0] }) ?? legacy,
                      FileManager.default.fileExists(atPath: path) else { continue }
                try? NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: path), for: screen, options: [:])
            }
            UserDefaults.standard.removeObject(forKey: savedWallpapersKey)
            UserDefaults.standard.removeObject(forKey: "macwatch.savedWallpaperPath")
            log("🖼️  Fond d'écran d'origine restauré.")
        }
    }

    static func lockScreen() {
        DispatchQueue.main.async {
            typealias LockFn = @convention(c) () -> Void
            guard let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
                  let sym = dlsym(handle, "SACLockScreenImmediate") else {
                log("Erreur : impossible de verrouiller l'écran via login.framework.")
                return
            }
            let lock = unsafeBitCast(sym, to: LockFn.self)
            lock()
            log("🔒 Écran verrouillé.")
        }
    }

    static func speakFlagAlertEnglish() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        if L10n.current == .fr {
            process.arguments = [
                "-v", "Thomas",
                "Vous n'êtes pas autorisé à toucher cet ordinateur. Une intrusion a été détectée. Cet ordinateur est verrouillé."
            ]
        } else {
            process.arguments = [
                "-v", "Samantha",
                "You are not authorized to touch this laptop. An intrusion was detected. This computer is locked."
            ]
        }
        try? process.run()
    }

    static func sendAlerts(config: Config, reason: String) {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        let message = "NyxWatch: \(reason) (\(timestamp))"
        if config.playAlarm { playAlarmSound() }
        if let endpoint = config.macStudioEndpoint, !endpoint.isEmpty {
            sendToMacStudio(endpoint: endpoint, reason: reason, timestamp: timestamp)
        }
        if let token = config.telegramBotToken, !token.isEmpty,
           let chat = config.telegramChatId, !chat.isEmpty {
            sendTelegram(token: token, chatId: chat, text: message)
        }
        if let target = config.imessageTarget, !target.isEmpty {
            sendIMessage(to: target, text: message)
        }
        if let phone = config.whatsappTarget, !phone.isEmpty {
            if isLocalBridgeLinked() {
                sendWhatsAppLocalBridge(phone: phone, text: message)
            } else if let key = config.callMeBotKey, !key.isEmpty {
                sendWhatsAppCallMeBot(phone: phone, text: message, apiKey: key)
            } else {
                sendWhatsAppDesktop(phone: phone, text: message, autoSend: config.whatsappAutoSend)
            }
        }
    }

    private static func sendToMacStudio(endpoint: String, reason: String, timestamp: String) {
        guard let url = URL(string: endpoint) else { return }
        let payload = ["app": "NyxWatch", "timestamp": timestamp, "reason": reason]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 10

        URLSession.shared.dataTask(with: req) { _, response, error in
            if let error {
                log("Erreur envoi Mac Studio : \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                log("📍 Alerte envoyée au Mac Studio (\(endpoint)).")
            } else {
                log("Erreur HTTP Mac Studio.")
            }
        }.resume()
    }

    private static func sendTelegram(token: String, chatId: String, text: String) {
        guard let url = URL(string: "https://api.telegram.org/bot\(token)/sendMessage") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["chat_id": chatId, "text": text])
        URLSession.shared.dataTask(with: req) { _, response, error in
            if let error {
                log("Erreur Telegram : \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                log("Notification Telegram envoyée.")
            } else {
                log("Erreur HTTP Telegram.")
            }
        }.resume()
    }

    private static func playAlarmSound() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        process.arguments = ["/System/Library/Sounds/Sosumi.aiff"]
        try? process.run()
    }

    private static func escapeAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func sendIMessage(to target: String, text: String) {
        let safeTarget = escapeAppleScript(target)
        let safeText = escapeAppleScript(text)

        var script = """
        tell application "Messages"
            set targetAccount to 1st account whose service type = iMessage
            set targetBuddy to participant "\(safeTarget)" of targetAccount
            send "\(safeText)" to targetBuddy
        """

        script += "\nend tell"

        let result = runOsascript(script)
        if result.exitCode == 0 {
            log("Notification iMessage envoyée à \(target).")
        } else {
            log("Erreur iMessage : \(result.stderr)")
        }
    }

    private static func sendWhatsAppDesktop(phone: String, text: String, autoSend: Bool) {
        let cleanPhone = phone.filter { $0.isNumber }
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "whatsapp://send?phone=\(cleanPhone)&text=\(encodedText)") else {
            log("Erreur : numéro WhatsApp invalide.")
            return
        }

        DispatchQueue.main.async {
            let opened = NSWorkspace.shared.open(url)
            if opened {
                log("WhatsApp Desktop ouvert pour \(phone).")
                if autoSend {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.8) {
                        let script = """
                        tell application "WhatsApp" to activate
                        delay 0.5
                        tell application "System Events"
                            keystroke return
                        end tell
                        """
                        let res = runOsascript(script)
                        if res.exitCode == 0 {
                            log("Message WhatsApp envoyé automatiquement.")
                        } else {
                            log("Erreur auto-envoi WhatsApp (vérifiez Accessibilité) : \(res.stderr)")
                        }
                    }
                }
            } else {
                log("WhatsApp Desktop non trouvé. Installez WhatsApp pour Mac ou utilisez --callmebot-key.")
            }
        }
    }

    private static func sendWhatsAppCallMeBot(phone: String, text: String, apiKey: String) {
        let cleanPhone = phone.filter { $0.isNumber }
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.callmebot.com/whatsapp.php?phone=\(cleanPhone)&text=\(encodedText)&apikey=\(apiKey)") else {
            log("Erreur URL CallMeBot.")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { _, response, error in
            if let error {
                log("Erreur WhatsApp (CallMeBot) : \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                log("Notification WhatsApp (CallMeBot) envoyée à \(phone).")
            } else {
                log("Erreur HTTP WhatsApp (CallMeBot).")
            }
        }
        task.resume()
    }

    static func bridgeScriptPath() -> String {
        NSString(string: "~/.macwatch/wa-bridge/wa-bridge.mjs").expandingTildeInPath
    }

    static func bridgeCredsPath() -> String {
        NSString(string: "~/.macwatch/wa-auth/creds.json").expandingTildeInPath
    }

    static func findNodeBinary() -> String? {
        let candidates = [
            NSString(string: "~/.local/bin/node").expandingTildeInPath,
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func isLocalBridgeLinked() -> Bool {
        FileManager.default.fileExists(atPath: bridgeCredsPath())
            && FileManager.default.fileExists(atPath: bridgeScriptPath())
            && findNodeBinary() != nil
    }

    private struct PendingAlert: Codable {
        let phone: String
        let text: String
    }

    private static let pendingQueueLock = NSLock()
    private static var retryTimer: Timer?

    private static func pendingQueuePath() -> String {
        NSString(string: "~/.macwatch/pending_text_alerts_v2.json").expandingTildeInPath
    }

    static func startRetryLoop() {
        DispatchQueue.main.async {
            guard retryTimer == nil else { return }
            retryTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
                processPendingAlerts()
            }
            processPendingAlerts()
        }
    }

    private static func loadPendingAlerts() -> [PendingAlert] {
        let path = pendingQueuePath()
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let list = try? JSONDecoder().decode([PendingAlert].self, from: data) else {
            return []
        }
        return list
    }

    private static func savePendingAlerts(_ alerts: [PendingAlert]) {
        let path = pendingQueuePath()
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if alerts.isEmpty {
            try? FileManager.default.removeItem(at: url)
        } else if let data = try? JSONEncoder().encode(alerts) {
            try? data.write(to: url)
        }
    }

    private static func enqueuePendingAlert(_ alert: PendingAlert) {
        pendingQueueLock.lock()
        defer { pendingQueueLock.unlock() }
        var list = loadPendingAlerts()
        list.append(alert)
        savePendingAlerts(list)
        log("⏳ Réseau indisponible — alerte mise en file d'attente (\(list.count) en attente).")
    }

    static func processPendingAlerts() {
        guard isLocalBridgeLinked() else { return }
        pendingQueueLock.lock()
        let list = loadPendingAlerts()
        if list.isEmpty {
            pendingQueueLock.unlock()
            return
        }
        savePendingAlerts([])
        pendingQueueLock.unlock()

        for alert in list {
            sendWhatsAppLocalBridge(
                phone: alert.phone,
                text: alert.text,
                isRetry: true
            )
        }
    }

    private static func sendWhatsAppLocalBridge(
        phone: String,
        text: String,
        isRetry: Bool = false
    ) {
        guard let nodePath = findNodeBinary() else {
            log("Erreur : binaire node introuvable pour le bridge WhatsApp.")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: nodePath)

            let args = [bridgeScriptPath(), "--to", phone, "--text", text]
            process.arguments = args

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            do {
                try process.run()
                process.waitUntilExit()
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let outStr = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if process.terminationStatus == 0 {
                    log(outStr.isEmpty ? "Notification WhatsApp (invisible) envoyée à \(phone)." : outStr)
                } else {
                    log("Erreur bridge WhatsApp (\(process.terminationStatus)) : \(errStr)")
                    enqueuePendingAlert(PendingAlert(
                        phone: phone,
                        text: text
                    ))
                }
            } catch {
                log("Erreur lancement bridge WhatsApp : \(error.localizedDescription)")
                if !isRetry {
                    enqueuePendingAlert(PendingAlert(
                        phone: phone,
                        text: text
                    ))
                }
            }
        }
    }

    private static func runOsascript(_ script: String) -> (exitCode: Int32, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (process.terminationStatus, errStr)
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}
