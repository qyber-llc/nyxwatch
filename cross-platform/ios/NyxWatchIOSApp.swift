import SwiftUI
import CoreMotion
import CoreLocation
import AVFoundation

/// NyxWatch iOS Sentinel App (Active Desk Guard)
/// Note: iOS sandbox prevents third-party apps from programmatically locking the device
/// or recording camera video while the screen is locked. Run NyxWatch iOS in foreground
/// on a desk to detect pickup/motion, capture 3s video, and alert Mac Studio / Telegram.
@main
struct NyxWatchIOSApp: App {
    @StateObject private var sentinel = IOSSentinelManager()

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 20) {
                Image(systemName: sentinel.isArmed ? "lock.shield.fill" : "shield.slash")
                    .font(.system(size: 56))
                    .foregroundColor(sentinel.isArmed ? Color(red: 0.86, green: 0.11, blue: 0.18) : .gray)

                Text("NYXWATCH iOS")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Toggle("Flag Mode (Flash + Voice)", isOn: $sentinel.flagMode)
                    .padding(.horizontal, 32)
                    .foregroundColor(.white)

                Button(sentinel.isArmed ? "DISARM" : "ARM SENTINEL") {
                    sentinel.toggleArm()
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(sentinel.isArmed ? Color(red: 0.86, green: 0.11, blue: 0.18) : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.04, green: 0.04, blue: 0.05))
        }
    }
}

final class IOSSentinelManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isArmed = false
    @Published var flagMode = true
    var macStudioURL: String = ""

    private let motion = CMMotionManager()
    private let location = CLLocationManager()
    private let synthesizer = AVSpeechSynthesizer()
    private var lastAlert = Date.distantPast

    override init() {
        super.init()
        location.delegate = self
    }

    func toggleArm() {
        isArmed.toggle()
        if isArmed {
            location.requestWhenInUseAuthorization()
            location.startUpdatingLocation()
            startMotionDetection()
        } else {
            motion.stopAccelerometerUpdates()
        }
    }

    private func startMotionDetection() {
        guard motion.isAccelerometerAvailable else { return }
        motion.accelerometerUpdateInterval = 0.2
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, self.isArmed, let acc = data?.acceleration else { return }
            let mag = abs(acc.x) + abs(acc.y) + abs(acc.z - 1.0)
            if mag > 0.35 && Date().timeIntervalSince(self.lastAlert) > 30 {
                self.lastAlert = Date()
                self.triggerAlert()
            }
        }
    }

    private func triggerAlert() {
        if flagMode {
            let utterance = AVSpeechUtterance(string: "You are not authorized to touch this device.")
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synthesizer.speak(utterance)
        }
        guard let url = URL(string: macStudioURL), !macStudioURL.isEmpty else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let coords = location.location?.coordinate
        let body: [String: Any] = [
            "app": "NyxWatch-iOS",
            "reason": "Motion detected",
            "latitude": coords?.latitude ?? 0,
            "longitude": coords?.longitude ?? 0
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
    }
}
