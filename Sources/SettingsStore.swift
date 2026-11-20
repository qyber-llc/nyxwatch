import Foundation

final class SettingsStore {
    static let shared = SettingsStore()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let deviceName = "macwatch.deviceName"
        static let deviceIdentifier = "macwatch.deviceIdentifier"
        static let rssiThreshold = "macwatch.rssiThreshold"
        static let awayDelaySeconds = "macwatch.awayDelaySeconds"
        static let cooldownSeconds = "macwatch.cooldownSeconds"
        static let imessageTarget = "macwatch.imessageTarget"
        static let whatsappTarget = "macwatch.whatsappTarget"
        static let whatsappAutoSend = "macwatch.whatsappAutoSend"
        static let callMeBotKey = "macwatch.callMeBotKey"
        static let playAlarm = "macwatch.playAlarm"
        static let surveillanceMode = "macwatch.surveillanceMode"
        static let strictDisarm = "macwatch.strictDisarm"
        static let telegramBotToken = "macwatch.telegramBotToken"
        static let telegramChatId = "macwatch.telegramChatId"
        static let macStudioEndpoint = "macwatch.macStudioEndpoint"
    }

    func loadInto(_ config: inout Config) {
        if config.deviceName == nil {
            config.deviceName = defaults.string(forKey: Keys.deviceName)
        }
        if config.deviceIdentifier == nil {
            config.deviceIdentifier = defaults.string(forKey: Keys.deviceIdentifier)
        }
        if defaults.object(forKey: Keys.rssiThreshold) != nil {
            config.rssiThreshold = defaults.integer(forKey: Keys.rssiThreshold)
        }
        if defaults.object(forKey: Keys.awayDelaySeconds) != nil {
            config.awayDelaySeconds = defaults.double(forKey: Keys.awayDelaySeconds)
        }
        if defaults.object(forKey: Keys.cooldownSeconds) != nil {
            config.cooldownSeconds = defaults.double(forKey: Keys.cooldownSeconds)
        }
        if config.imessageTarget == nil {
            config.imessageTarget = defaults.string(forKey: Keys.imessageTarget)
        }
        if config.whatsappTarget == nil {
            config.whatsappTarget = defaults.string(forKey: Keys.whatsappTarget)
        }
        if defaults.object(forKey: Keys.whatsappAutoSend) != nil && !config.whatsappAutoSend {
            config.whatsappAutoSend = defaults.bool(forKey: Keys.whatsappAutoSend)
        }
        if config.callMeBotKey == nil {
            config.callMeBotKey = defaults.string(forKey: Keys.callMeBotKey)
        }
        if defaults.object(forKey: Keys.playAlarm) != nil && !config.playAlarm {
            config.playAlarm = defaults.bool(forKey: Keys.playAlarm)
        }
        if let rawMode = defaults.string(forKey: Keys.surveillanceMode),
           let mode = SurveillanceMode(rawValue: rawMode) {
            config.surveillanceMode = mode
        }
        if defaults.object(forKey: Keys.strictDisarm) != nil {
            config.strictDisarm = defaults.bool(forKey: Keys.strictDisarm)
        }
        if config.telegramBotToken == nil {
            config.telegramBotToken = defaults.string(forKey: Keys.telegramBotToken)
        }
        if config.telegramChatId == nil {
            config.telegramChatId = defaults.string(forKey: Keys.telegramChatId)
        }
        if config.macStudioEndpoint == nil {
            config.macStudioEndpoint = defaults.string(forKey: Keys.macStudioEndpoint)
        }
    }

    func save(from config: Config) {
        defaults.set(config.deviceName, forKey: Keys.deviceName)
        defaults.set(config.deviceIdentifier, forKey: Keys.deviceIdentifier)
        defaults.set(config.rssiThreshold, forKey: Keys.rssiThreshold)
        defaults.set(config.awayDelaySeconds, forKey: Keys.awayDelaySeconds)
        defaults.set(config.cooldownSeconds, forKey: Keys.cooldownSeconds)
        defaults.set(config.imessageTarget, forKey: Keys.imessageTarget)
        defaults.set(config.whatsappTarget, forKey: Keys.whatsappTarget)
        defaults.set(config.whatsappAutoSend, forKey: Keys.whatsappAutoSend)
        defaults.set(config.callMeBotKey, forKey: Keys.callMeBotKey)
        defaults.set(config.playAlarm, forKey: Keys.playAlarm)
        defaults.set(config.surveillanceMode.rawValue, forKey: Keys.surveillanceMode)
        defaults.set(config.strictDisarm, forKey: Keys.strictDisarm)
        defaults.set(config.telegramBotToken, forKey: Keys.telegramBotToken)
        defaults.set(config.telegramChatId, forKey: Keys.telegramChatId)
        defaults.set(config.macStudioEndpoint, forKey: Keys.macStudioEndpoint)
    }
}
