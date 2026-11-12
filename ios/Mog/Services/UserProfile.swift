import Foundation
import MogCore

/// Onboarding answers and consent state. Small, so UserDefaults is fine; nothing here is face data.
struct UserProfile: Codable {
    var onboardingComplete = false
    var goals: [String] = []              // ordered, up to 3, ids from rules.json goals
    var sex: Sex = .male                  // "reference table", not identity
    var ageBand: String = "18-24"
    var ageAttestedAt: Date? = nil        // we store the attestation time, never a DOB
    var timeBudgetMin: Int = 15
    var stateAttestation: String? = nil   // two-letter US state, or nil (non-US / not asked)
    var consentGranted = false
    var consentPolicyVersion: String? = nil
    var consentAt: Date? = nil
    var syncEnabled = false               // separate consent, off by default
    var profileCaptureEnabled = true

    static let blockedStates: Set<String> = ["IL", "TX", "WA"]
    var measurementBlockedByState: Bool { stateAttestation.map { Self.blockedStates.contains($0) } ?? false }

    private static let key = "mog.profile.v1"
    static func load() -> UserProfile {
        guard let d = UserDefaults.standard.data(forKey: key), let p = try? JSONDecoder().decode(UserProfile.self, from: d) else { return UserProfile() }
        return p
    }
    func save() { if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: Self.key) } }
    static func wipe() { UserDefaults.standard.removeObject(forKey: key) }
}

enum Policy {
    /// Bump when legal/biometric-data-policy.md changes; the consent screen re-prompts.
    static let biometricPolicyVersion = "1.0"
}
