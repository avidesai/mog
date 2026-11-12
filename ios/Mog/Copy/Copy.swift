import Foundation

/// All user-facing strings come from core/copy/strings.json (bundled). Nothing is hard-coded
/// in views, so the copy deck — and its denylist test — is the single source of truth.
///
///     Copy.s("today.title")                                   → "Today"
///     Copy.f("today.scan_countdown", ["days": "12"])          → "Next scan opens in 12 days"
///
/// `{app_name}` is substituted everywhere from `Copy.appName`.
enum Copy {
    static var appName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Mog"

    private static let table: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "strings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            assertionFailure("strings.json missing from bundle"); return [:]
        }
        return obj
    }()

    static func s(_ key: String) -> String {
        let parts = key.split(separator: ".").map(String.init)
        var node: Any? = table
        for p in parts { node = (node as? [String: Any])?[p] }
        guard let str = node as? String else {
            assertionFailure("missing copy key \(key)")
            return "⟨\(key)⟩"
        }
        return str.replacingOccurrences(of: "{app_name}", with: appName)
    }

    static func f(_ key: String, _ args: [String: String]) -> String {
        var out = s(key)
        for (k, v) in args { out = out.replacingOccurrences(of: "{\(k)}", with: v) }
        return out
    }
}
