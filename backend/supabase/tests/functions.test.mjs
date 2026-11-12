// node --experimental-strip-types --test tests/functions.test.mjs   (Node ≥ 22.6)
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Denylist } from "../functions/_shared/denylist.ts";
import { validateRequest, buildPrompt, validateAndScan } from "../functions/phrase/logic.ts";
import { mapEvent } from "../functions/revenuecat-webhook/logic.ts";

const deny = new Denylist(JSON.parse(readFileSync(new URL("../functions/_shared/denylist.json", import.meta.url), "utf8")));

test("denylist parity with the Python suite", () => {
  assert.equal(deny.isClean("Try bone smashing for your cheekbones"), false);
  assert.equal(deny.isClean("Take 1mg finasteride daily"), false);
  assert.equal(deny.isClean("Aim for 1800 kcal a day"), false);
  assert.equal(deny.isClean("Hard mewing fixes recession"), false);
  assert.equal(deny.isClean("You mog most people"), false);
  assert.equal(deny.isClean("Looks better than most people"), false);
  assert.equal(deny.isClean("consider leg-lengthening"), false);
  assert.equal(deny.isClean("try BPC-157"), false);
  assert.equal(deny.isClean("Reduce body fat at roughly half a percent of bodyweight per week."), true);
  assert.equal(deny.isClean("Daily broad-spectrum SPF 30 or higher."), true);
  const mew = "There is no evidence that mewing changes adult facial shape.";
  assert.equal(deny.isClean(mew), false);
  assert.equal(deny.isClean(mew, true), true);
});

const goodReq = {
  goals: ["sharper_jawline"], time_budget_min: 15,
  cards: [{ rule_id: "spf_daily", headline: "Daily broad-spectrum SPF", body: "Sun exposure drives unevenness.", why_this: "Foundational.",
            evidence_grade: "strong", finding_categories: [{ metric_id: "skin_evenness", category: "low" }] }],
};

test("phrase request validation refuses anything non-categorical", () => {
  assert.ok(validateRequest(goodReq));
  assert.equal(validateRequest({ ...goodReq, goals: ["win"] }), null);
  assert.equal(validateRequest({ ...goodReq, time_budget_min: 10 }), null);
  assert.equal(validateRequest({ ...goodReq, cards: [] }), null);
  const withValue = structuredClone(goodReq); withValue.cards[0].finding_categories[0].value = 0.42;
  assert.equal(validateRequest(withValue), null, "a measurement value must be refused");
  const withScore = structuredClone(goodReq); withScore.cards[0].score = 6.4;
  assert.equal(validateRequest(withScore), null, "a score must be refused");
  const withLandmarks = structuredClone(goodReq); withLandmarks.cards[0].landmarks = [[0.1, 0.2]];
  assert.equal(validateRequest(withLandmarks), null);
});

test("prompt never carries numbers beyond the time budget", () => {
  const p = buildPrompt(goodReq);
  assert.ok(p);
  assert.match(p.user, /"time_budget_min":15/);
  assert.doesNotMatch(p.user, /score|percentile|value/);
});

test("model output: schema + denylist gate", () => {
  const ok = JSON.stringify({ cards: [{ rule_id: "spf_daily", body: "Sun is the main driver of uneven tone; a broad-spectrum sunscreen every morning is the habit with the highest return.", why_this: "Your skin evenness reads below typical." }] });
  assert.ok(validateAndScan(ok, goodReq, deny));
  const wrongOrder = JSON.stringify({ cards: [{ rule_id: "other", body: "x", why_this: "y" }] });
  assert.equal(validateAndScan(wrongOrder, goodReq, deny), null);
  const addedDose = JSON.stringify({ cards: [{ rule_id: "spf_daily", body: "Use 0.5mg tretinoin nightly.", why_this: "y" }] });
  assert.equal(validateAndScan(addedDose, goodReq, deny), null);
  const comparative = JSON.stringify({ cards: [{ rule_id: "spf_daily", body: "You will look better than most people.", why_this: "y" }] });
  assert.equal(validateAndScan(comparative, goodReq, deny), null);
  const excl = JSON.stringify({ cards: [{ rule_id: "spf_daily", body: "Great start! Keep going.", why_this: "y" }] });
  assert.equal(validateAndScan(excl, goodReq, deny), null, "exclamation marks are out of voice");
  const wrapped = "Here you go:\n" + ok + "\nHope that helps";
  assert.ok(validateAndScan(wrapped, goodReq, deny), "tolerates prose around the JSON");
  assert.equal(validateAndScan("not json", goodReq, deny), null);
});

test("revenuecat events map to entitlement rows; anonymous ids are dropped", () => {
  const uid = "00000000-0000-0000-0000-000000000001";
  const t = Date.now() + 86400e3;
  assert.deepEqual(mapEvent({ type: "INITIAL_PURCHASE", app_user_id: uid, product_id: "annual_3499_trial3d", period_type: "TRIAL", expiration_at_ms: t }),
    { user_id: uid, product: "annual_3499_trial3d", status: "trial", expires_at: new Date(t).toISOString(), source: "revenuecat" });
  assert.equal(mapEvent({ type: "RENEWAL", app_user_id: uid, product_id: "weekly_499", period_type: "NORMAL", expiration_at_ms: t }).status, "active");
  assert.equal(mapEvent({ type: "CANCELLATION", app_user_id: uid, product_id: "weekly_499", period_type: "NORMAL", expiration_at_ms: t }).status, "active", "cancelled but not yet expired keeps access");
  assert.equal(mapEvent({ type: "CANCELLATION", app_user_id: uid, product_id: "weekly_499", period_type: "NORMAL", expiration_at_ms: Date.now() - 1000 }).status, "expired");
  assert.equal(mapEvent({ type: "EXPIRATION", app_user_id: uid, product_id: "weekly_499" }).status, "expired");
  assert.equal(mapEvent({ type: "REFUND", app_user_id: uid, product_id: "lifetime_5999" }).status, "refunded");
  assert.deepEqual(mapEvent({ type: "NON_RENEWING_PURCHASE", app_user_id: uid, product_id: "lifetime_5999" }).expires_at, null);
  assert.equal(mapEvent({ type: "TEST", app_user_id: uid, product_id: "weekly_499" }), null);
  assert.equal(mapEvent({ type: "RENEWAL", app_user_id: "$RCAnonymousID:abc", product_id: "weekly_499" }), null);
});
