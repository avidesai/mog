import Foundation

/// The capture gates read their labels and hints from core/copy/strings.json (bundled), the same
/// deck the Exact app uses, so the spike tools show the wording a person will see.
///
///     Copy.s("capture.hint_ready")
enum Copy {
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
        return str
    }
}
