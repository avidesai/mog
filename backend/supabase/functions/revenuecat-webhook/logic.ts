// Pure mapping from a RevenueCat webhook event to an entitlements row. Tested with Node.

export interface EntitlementRow { user_id: string; product: string; status: "active" | "expired" | "refunded" | "trial"; expires_at: string | null; source: "revenuecat" }

const UUID_RX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Returns null for events we ignore (TEST, TRANSFER, SUBSCRIBER_ALIAS, unknown users). */
export function mapEvent(ev: any): EntitlementRow | null {
  if (!ev || typeof ev !== "object") return null;
  const userId: string | undefined = ev.app_user_id;
  if (!userId || !UUID_RX.test(userId)) return null;         // anonymous RevenueCat ids are never persisted
  const product: string | undefined = ev.product_id;
  if (!product) return null;
  const expiresAt = typeof ev.expiration_at_ms === "number" ? new Date(ev.expiration_at_ms).toISOString() : null;
  let status: EntitlementRow["status"];
  switch (ev.type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "UNCANCELLATION":
    case "PRODUCT_CHANGE":
    case "NON_RENEWING_PURCHASE":
      status = ev.period_type === "TRIAL" ? "trial" : "active"; break;
    case "CANCELLATION":                 // auto-renew off; access continues until expiration
      status = expiresAt && new Date(expiresAt) > new Date() ? (ev.period_type === "TRIAL" ? "trial" : "active") : "expired"; break;
    case "EXPIRATION":
    case "BILLING_ISSUE":
      status = "expired"; break;
    case "REFUND":
      status = "refunded"; break;
    default:
      return null;                       // TEST, TRANSFER, SUBSCRIBER_ALIAS, SUBSCRIPTION_PAUSED, etc.
  }
  // lifetime products never expire
  if (product.startsWith("lifetime")) return { user_id: userId, product, status: status === "refunded" ? "refunded" : "active", expires_at: null, source: "revenuecat" };
  return { user_id: userId, product, status, expires_at: expiresAt, source: "revenuecat" };
}
