import Foundation

/// Purchases live behind a protocol so the whole app builds and runs with zero network
/// dependencies during the spikes. Week 5 adds `RevenueCatPurchases` and swaps it in AppModel.
protocol Purchases: AnyObject {
    func isPro() async -> Bool
    func offerings() async -> [Offering]
    func purchase(_ offering: Offering) async throws -> Bool
    func restore() async throws -> Bool
}

struct Offering: Identifiable, Hashable {
    enum Kind { case weekly, annual }
    let id: String
    let kind: Kind
    let priceString: String
}

/// Debug stub: no purchase ever happens; "Pro" toggles in Settings under DEBUG.
final class PurchasesStub: Purchases {
    static var debugPro = false
    func isPro() async -> Bool { Self.debugPro }
    func offerings() async -> [Offering] {
        [Offering(id: "pro.weekly", kind: .weekly, priceString: "$4.99"),
         Offering(id: "pro.annual", kind: .annual, priceString: "$34.99")]
    }
    func purchase(_ offering: Offering) async throws -> Bool { false }
    func restore() async throws -> Bool { Self.debugPro }
}
