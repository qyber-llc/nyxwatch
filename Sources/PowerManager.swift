import Foundation
import IOKit.pwr_mgt

final class PowerManager {
    private var assertionID: IOPMAssertionID = 0
    private var isHoldingAssertion = false

    func preventSleep() {
        guard !isHoldingAssertion else { return }
        let reason = "MacWatch garde le MacBook éveillé pour la surveillance" as CFString
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        if status == kIOReturnSuccess {
            isHoldingAssertion = true
            log("Maintien en éveil activé (IOPMAssertion).")
        } else {
            log("Avertissement : impossible d'activer l'assertion anti-veille (code \(status)).")
        }
    }

    func allowSleep() {
        guard isHoldingAssertion else { return }
        IOPMAssertionRelease(assertionID)
        isHoldingAssertion = false
    }

    deinit {
        allowSleep()
    }
}
