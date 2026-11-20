import Foundation

enum SurveillanceMode: String {
    case discreet
    case flag
}

struct Config {
    enum Mode {
        case monitor
        case scan
        case testAlert
    }

    var mode: Mode = .monitor
    var surveillanceMode: SurveillanceMode = .discreet
    var deviceName: String?
    var deviceIdentifier: String?
    var rssiThreshold: Int = -75
    var awayDelaySeconds: TimeInterval = 10.0
    var armSettleSeconds: TimeInterval = 3.0
    var cooldownSeconds: TimeInterval = 30.0
    var imessageTarget: String?
    var whatsappTarget: String?
    var whatsappAutoSend: Bool = false
    var callMeBotKey: String?
    var telegramBotToken: String?
    var telegramChatId: String?
    var macStudioEndpoint: String?
    var armImmediately: Bool = false
    var playAlarm: Bool = false
    var strictDisarm: Bool = false
    var verbose: Bool = false

    static func parse(arguments: [String] = CommandLine.arguments) -> Config {
        var config = Config()
        var i = 1
        while i < arguments.count {
            let arg = arguments[i]
            switch arg {
            case "--scan", "-s":
                config.mode = .scan
            case "--test-alert":
                config.mode = .testAlert
            case "--device", "-d":
                i += 1
                if i < arguments.count { config.deviceName = arguments[i] }
            case "--id", "-i":
                i += 1
                if i < arguments.count { config.deviceIdentifier = arguments[i] }
            case "--rssi", "-r":
                i += 1
                if i < arguments.count, let val = Int(arguments[i]) {
                    config.rssiThreshold = val
                }
            case "--away-delay":
                i += 1
                if i < arguments.count, let val = Double(arguments[i]) {
                    config.awayDelaySeconds = val
                }
            case "--cooldown":
                i += 1
                if i < arguments.count, let val = Double(arguments[i]) {
                    config.cooldownSeconds = val
                }
            case "--imessage", "-m":
                i += 1
                if i < arguments.count { config.imessageTarget = arguments[i] }
            case "--whatsapp", "-w":
                i += 1
                if i < arguments.count { config.whatsappTarget = arguments[i] }
            case "--whatsapp-autosend":
                config.whatsappAutoSend = true
            case "--callmebot-key":
                i += 1
                if i < arguments.count { config.callMeBotKey = arguments[i] }
            case "--telegram-token":
                i += 1
                if i < arguments.count { config.telegramBotToken = arguments[i] }
            case "--telegram-chat":
                i += 1
                if i < arguments.count { config.telegramChatId = arguments[i] }
            case "--arm-now":
                config.armImmediately = true
            case "--alarm":
                config.playAlarm = true
            case "--mode":
                i += 1
                if i < arguments.count, let parsed = SurveillanceMode(rawValue: arguments[i].lowercased()) {
                    config.surveillanceMode = parsed
                }
            case "--verbose", "-v":
                config.verbose = true
            case "--help", "-h":
                printHelp()
                exit(0)
            default:
                log("Option inconnue ignorée : \(arg)")
            }
            i += 1
        }
        return config
    }

    static func printHelp() {
        let help = """
        NyxWatch - Surveillance automatique par proximité Bluetooth

        USAGE:
          NyxWatch --scan
              Liste les appareils Bluetooth appairés et les périphériques BLE détectés.

          NyxWatch --device "iPhone de Alex" --imessage "+33612345678" [options]
              Lance la surveillance. Arme le Mac quand vous vous éloignez, verrouille le Mac
              et envoie une alerte si quelqu'un touche au clavier/trackpad/souris.

          NyxWatch --test-alert --imessage "+33612345678"
              Teste la notification sans verrouiller le Mac.

        OPTIONS:
          -s, --scan                  Scanner les appareils Bluetooth à proximité
          -d, --device <nom>          Nom (ou partie du nom) de votre appareil Bluetooth
          -i, --id <uuid|mac>         UUID BLE ou adresse MAC Bluetooth de votre appareil
          -r, --rssi <dBm>            Seuil RSSI pour considérer que vous êtes loin (défaut: -75)
              --away-delay <sec>      Secondes hors de portée avant armement (défaut: 10)
              --cooldown <sec>        Délai minimum entre deux alertes (défaut: 30)
          -m, --imessage <numéro>     Numéro ou email Apple pour alerte iMessage
          -w, --whatsapp <numéro>     Numéro WhatsApp (format international, ex: +33612345678)
              --whatsapp-autosend     Simule Entrée dans WhatsApp Desktop pour envoyer
              --callmebot-key <clé>   Clé API CallMeBot pour envoi WhatsApp silencieux
              --arm-now               Armer immédiatement au lancement (mode test/manuel)
              --alarm                 Jouer un son d'alerte lors d'une intrusion
              --mode <discreet|flag>  Alerte + verrouillage, avec avertissement en mode Flag
          -v, --verbose               Afficher les mesures RSSI et logs détaillés
          -h, --help                  Afficher cette aide
        """
        print(help)
    }
}

func log(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    let ts = formatter.string(from: Date())
    print("[\(ts)] \(message)")
    fflush(stdout)
}
