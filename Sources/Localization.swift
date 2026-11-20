import Foundation

enum AppLanguage: String {
    case fr
    case en
}

enum L10n {
    static var current: AppLanguage = {
        if let saved = UserDefaults.standard.string(forKey: "macwatch.language"),
           let lang = AppLanguage(rawValue: saved) {
            return lang
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.lowercased().hasPrefix("fr") ? .fr : .en
    }()

    static func t(_ fr: String, _ en: String) -> String {
        current == .fr ? fr : en
    }
}
