#!/usr/bin/env python3
"""Verify the macOS release cannot collect media/input and sends text-only payloads.
Run on macOS: python3 tests/privacy_regression.py
"""
from pathlib import Path
import plistlib
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
sources = '\n'.join(p.read_text() for p in (root / 'Sources').glob('*.swift'))
for forbidden in ('addGlobalMonitorForEvents', 'CGEventTapCreate', 'CGWindowListCopyWindowInfo',
                  'CGRequestScreenCaptureAccess', 'CGPreflightScreenCaptureAccess',
                  '/usr/sbin/screencapture', 'AVCapture', 'ScreenCaptureKit',
                  'event.characters', 'typedBuffer', 'ForensicSessionMonitor', 'AISummarizer',
                  'CameraCapture', 'FaceAnalyzer', 'LocationHelper', 'mediaPath', 'photoURL'):
    assert forbidden not in sources, forbidden
info = plistlib.loads((root / 'Info.plist').read_bytes())
for permission in ('NSCameraUsageDescription', 'NSMicrophoneUsageDescription', 'NSLocationUsageDescription'):
    assert permission not in info, permission
entitlements = plistlib.loads((root / 'packaging/entitlements.plist').read_bytes())
assert entitlements == {'com.apple.security.automation.apple-events': True}
notifier = (root / 'Sources/Notifier.swift').read_text()
assert 'pending_text_alerts_v2.json' in notifier
assert 'pending_alerts.json' not in notifier
controller = (root / 'Sources/main.swift').read_text()
alert = controller.split('private func triggerAlert(', 1)[1].split('private func launchWhatsAppLoginInTerminal', 1)[0]
assert 'Notifier.lockScreen()' in alert and 'surveillanceMode == .flag' in alert
assert alert.index('Notifier.lockScreen()') < alert.index('DispatchQueue.global')
assert 'Notifier.sendAlerts' in alert

# Exercise the actual notification implementation with intercepted requests.
# No real network, camera, alert sound, lock or messaging application is used.
swift_test = r'''
import Foundation
import AppKit

final class RequestProbe: URLProtocol {
    static let guardLock = NSLock()
    static var payloads: [[String: Any]] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, url.host == "nyxwatch.invalid" || url.host == "api.telegram.org" else {
            fatalError("Unexpected destination")
        }
        var body = request.httpBody
        if body == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var bytes = [UInt8](repeating: 0, count: 1024)
            var data = Data()
            while stream.hasBytesAvailable {
                let n = stream.read(&bytes, maxLength: bytes.count)
                if n <= 0 { break }
                data.append(contentsOf: bytes.prefix(n))
            }
            body = data
        }
        let json = try! JSONSerialization.jsonObject(with: body!) as! [String: Any]
        Self.guardLock.lock()
        Self.payloads.append(json)
        Self.guardLock.unlock()
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
URLProtocol.registerClass(RequestProbe.self)
var config = Config()
config.macStudioEndpoint = "https://nyxwatch.invalid/alert"
config.telegramBotToken = "test-token"
config.telegramChatId = "test-chat"
Notifier.sendAlerts(config: config, reason: "USB connected")
let deadline = Date().addingTimeInterval(5)
var payloads: [[String: Any]] = []
while Date() < deadline {
    RequestProbe.guardLock.lock()
    payloads = RequestProbe.payloads
    RequestProbe.guardLock.unlock()
    if payloads.count == 2 { break }
    RunLoop.current.run(until: Date().addingTimeInterval(0.02))
}
precondition(payloads.count == 2, "Expected two intercepted text notifications")
let lan = payloads.first { $0["app"] != nil }!
precondition(Set(lan.keys) == Set(["app", "reason", "timestamp"]))
precondition(lan["reason"] as? String == "USB connected")
let telegram = payloads.first { $0["chat_id"] != nil }!
precondition(Set(telegram.keys) == Set(["chat_id", "text"]))
precondition((telegram["text"] as! String).contains("USB connected"))
print("PASS: text-only notification delivery; no recording APIs or permissions")
'''
with tempfile.TemporaryDirectory(prefix='nyxwatch-privacy-test-') as tmp:
    tmp = Path(tmp)
    (tmp / 'main.swift').write_text(swift_test)
    subprocess.run(['swiftc', '-framework', 'AppKit',
                    str(root / 'Sources/Config.swift'), str(root / 'Sources/Localization.swift'),
                    str(root / 'Sources/Notifier.swift'), str(tmp / 'main.swift'),
                    '-o', str(tmp / 'privacy-test')], check=True)
    subprocess.run([str(tmp / 'privacy-test')], check=True, timeout=15)
