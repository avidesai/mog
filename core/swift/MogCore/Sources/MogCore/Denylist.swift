import Foundation

// Mirrors mogcore/denylist.py. Render-time use: scan every LLM-generated string;
// on any hit, discard the generation and use the rule's static copy.

public struct DenyHit { public let pattern: String; public let reason: String; public let match: String }

public final class Denylist {
    private struct Term: Codable { let pattern: String; let word: Bool?; let allow_in_info: Bool?; let regex: Bool?; let reason: String }
    private struct File: Codable { let terms: [Term]; let allowed_in_tier_3_4_copy: [String]? }
    private let compiled: [(NSRegularExpression, String, String, Bool)]
    public let allowedInProfessional: [String]

    public init(data: Data) throws {
        let f = try JSONDecoder().decode(File.self, from: data)
        var out: [(NSRegularExpression, String, String, Bool)] = []
        for t in f.terms {
            var pat = t.pattern
            if !(t.regex ?? false) {
                pat = NSRegularExpression.escapedPattern(for: pat).replacingOccurrences(of: "\\?", with: "?")
                if t.word ?? false { pat = "\\b\(pat)\\b" }
            }
            out.append((try NSRegularExpression(pattern: pat, options: [.caseInsensitive]), t.pattern, t.reason, t.allow_in_info ?? false))
        }
        compiled = out
        allowedInProfessional = f.allowed_in_tier_3_4_copy ?? []
    }

    public func scan(_ text: String, infoCard: Bool = false) -> [DenyHit] {
        var hits: [DenyHit] = []
        let ns = text as NSString
        for (rx, label, reason, allowInfo) in compiled {
            if infoCard && allowInfo { continue }
            if let m = rx.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) {
                hits.append(DenyHit(pattern: label, reason: reason, match: ns.substring(with: m.range)))
            }
        }
        return hits
    }
    public func isClean(_ text: String, infoCard: Bool = false) -> Bool { scan(text, infoCard: infoCard).isEmpty }
}
