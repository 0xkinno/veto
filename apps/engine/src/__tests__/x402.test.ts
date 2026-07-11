import { describe, it, expect } from "vitest";
import { toAtomic, requirementsFor, challengeFor } from "../x402/pricing";
import { paymentConfigured } from "../x402/facilitator";

describe("x402 pricing", () => {
  it("converts human prices to 6-decimal atomic units", () => {
    expect(toAtomic("0.15")).toBe("150000");
    expect(toAtomic("1")).toBe("1000000");
    expect(toAtomic("0.5")).toBe("500000");
    expect(toAtomic("0.000001")).toBe("1");
  });

  it("builds PaymentRequirements with the right scheme + network", () => {
    const r = requirementsFor("verdict", "https://veto.dev/verdict");
    expect(r.scheme).toBe("exact");
    expect(r.network).toBe("eip155:196");
    expect(r.amount).toBe("150000"); // 0.15 default
    expect(r.asset).toMatch(/^0x[0-9a-fA-F]{40}$/);
  });

  it("builds a 402 challenge with an accepts array", () => {
    const c = challengeFor("forensics", "https://veto.dev/forensics");
    expect(c.x402Version).toBe(2);
    expect(Array.isArray(c.accepts)).toBe(true);
    expect(c.accepts[0].amount).toBe("500000"); // 0.50
  });

  it("reports payment unconfigured when keys are absent", () => {
    // No OKX_* env in test -> gate stays open (dev mode).
    expect(paymentConfigured()).toBe(false);
  });
});
