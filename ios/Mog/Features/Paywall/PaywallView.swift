import SwiftUI

/// Value-first hard paywall. Price, period and renewal terms on the surface; close control
/// visible from the first frame; restore on every paywall; no scarcity, no social proof.
/// Superwall will own the layout in week 5 — this is the compliant fallback it must match.
struct PaywallView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let placement: String
    @State private var offerings: [Offering] = []
    @State private var chosen: Offering?
    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); Button(Copy.s("common.close")) { app.analytics.track(.paywallDismissed); dismiss() }.foregroundStyle(Tokens.Colors.ink500) }
                .padding(.horizontal, Tokens.Space.s5).padding(.top, Tokens.Space.s4)
            Screen {
                Text(Copy.s("paywall.title")).style(TypeStyle.displayTitle)
                Text(Copy.s("paywall.intro")).style(TypeStyle.body, color: Tokens.Colors.ink700)
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    ForEach(["paywall.includes_1", "paywall.includes_2", "paywall.includes_3", "paywall.includes_4", "paywall.includes_5"], id: \.self) { k in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Tokens.Colors.accent).padding(.top, 4)
                            Text(Copy.f(k, ["n": "\(app.registry.metrics.count)"])).style(TypeStyle.body)
                        }
                    }
                }
                VStack(spacing: Tokens.Space.s3) {
                    ForEach(offerings) { o in
                        OptionRow(title: title(o), subtitle: o.kind == .annualTrial ? Copy.f("paywall.plan_annual_trial", ["price_annual": o.priceString]) : nil,
                                  selected: chosen?.id == o.id) { chosen = o }
                    }
                }
                Text(Copy.s("paywall.renewal_terms")).style(TypeStyle.caption, color: Tokens.Colors.ink500)
                HStack(spacing: Tokens.Space.s3) {
                    Link(Copy.s("common.terms"), destination: URL(string: "https://example.invalid/terms")!)
                    Link(Copy.s("common.privacy"), destination: URL(string: "https://example.invalid/privacy")!)
                    Spacer()
                    Button(Copy.s("common.restore_purchases")) { Task { if (try? await app.purchases.restore()) == true { app.isPro = true; dismiss() } } }
                }.font(TypeStyle.detail.font).foregroundStyle(Tokens.Colors.ink500)
            }
            footer {
                Button(Copy.s("paywall.cta")) { buy() }.buttonStyle(.chunky).disabled(chosen == nil || busy).opacity(chosen == nil ? 0.5 : 1)
                Button(Copy.s("paywall.keep_free")) { app.analytics.track(.paywallDismissed); dismiss() }.buttonStyle(.quiet)
            }
        }
        .background(Tokens.Colors.paper)
        .task {
            app.analytics.track(.paywallViewed(placement: placement))
            offerings = await app.purchases.offerings()
            chosen = offerings.first { $0.kind == .annualTrial }
        }
    }

    private func title(_ o: Offering) -> String {
        switch o.kind {
        case .weekly: return Copy.f("paywall.plan_weekly", ["price_weekly": o.priceString])
        case .annualTrial: return Copy.f("paywall.plan_annual", ["price_annual": o.priceString])
        case .lifetime: return Copy.f("paywall.plan_lifetime", ["price_lifetime": o.priceString])
        }
    }

    private func buy() {
        guard let o = chosen else { return }
        busy = true
        app.analytics.track(.purchaseStarted(product: o.id))
        Task {
            let ok = (try? await app.purchases.purchase(o)) ?? false
            busy = false
            if ok { app.isPro = true; app.analytics.track(.purchaseCompleted(product: o.id)); dismiss() }
        }
    }
}
