import Foundation
import os

/// A closed allowlist of events. Nothing else can be sent. Payloads carry no score, no metric
/// value, no image or derivative, no goal text — only categorical state (eng doc, "Privacy").
/// The transport is a no-op logger until PostHog is wired in week 7; the allowlist is the point.
enum AnalyticsEvent {
    case onboardingStep(String)
    case consentGranted, consentDeclined
    case captureGateFailed(gate: String)
    case captureAborted(gate: String)
    case captureCompleted(pose: String)
    case scoreComputed(nScored: Int)
    case resultsOpened
    case metricOpened(metric: String)
    case paywallViewed(placement: String), paywallDismissed, purchaseStarted(product: String), purchaseCompleted(product: String)
    case taskCompleted(rule: String), dayCompleted(week: Int), weekBanked(week: Int)
    case repairUsed
    case scanRecorded(week: Int)
    case distressCardShown
    case deleteEverything

    var name: String {
        switch self {
        case .onboardingStep: return "onboarding_step"
        case .consentGranted: return "consent_granted"
        case .consentDeclined: return "consent_declined"
        case .captureGateFailed: return "capture_gate_failed"
        case .captureAborted: return "capture_aborted"
        case .captureCompleted: return "capture_completed"
        case .scoreComputed: return "score_computed"
        case .resultsOpened: return "results_opened"
        case .metricOpened: return "metric_opened"
        case .paywallViewed: return "paywall_viewed"
        case .paywallDismissed: return "paywall_dismissed"
        case .purchaseStarted: return "purchase_started"
        case .purchaseCompleted: return "purchase_completed"
        case .taskCompleted: return "task_completed"
        case .dayCompleted: return "day_completed"
        case .weekBanked: return "week_banked"
        case .repairUsed: return "repair_used"
        case .scanRecorded: return "scan_recorded"
        case .distressCardShown: return "distress_card_shown"
        case .deleteEverything: return "delete_everything"
        }
    }

    var properties: [String: String] {
        switch self {
        case .onboardingStep(let s): return ["step": s]
        case .captureGateFailed(let g), .captureAborted(let g): return ["gate": g]
        case .captureCompleted(let p): return ["pose": p]
        case .scoreComputed(let n): return ["n_scored": "\(n)"]   // a count, never a value
        case .metricOpened(let m): return ["metric": m]
        case .paywallViewed(let p): return ["placement": p]
        case .purchaseStarted(let p), .purchaseCompleted(let p): return ["product": p]
        case .taskCompleted(let r): return ["rule": r]
        case .dayCompleted(let w), .weekBanked(let w), .scanRecorded(let w): return ["week": "\(w)"]
        default: return [:]
        }
    }
}

final class Analytics {
    private let log = Logger(subsystem: "com.avidesai.mog", category: "analytics")
    func track(_ e: AnalyticsEvent) {
        // TODO(week 7): PostHog capture(e.name, properties: e.properties). Never add a property here
        // that isn't categorical; the MITM audit will catch it, but don't make it find anything.
        log.info("\(e.name, privacy: .public) \(e.properties.description, privacy: .public)")
    }
}
