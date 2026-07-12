import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";

/**
 * The gate must be OPEN with no OKX keys (so the engine is runnable), and
 * must ENFORCE the moment all four payment vars are set. Getting this wrong
 * means either a broken engine or an ASP that serves paid work for free.
 */

const KEYS = [
  "OKX_API_KEY",
  "OKX_API_SECRET",
  "OKX_API_PASSPHRASE",
  "VETO_PAYTO_ADDRESS",
] as const;

function clearKeys() {
  for (const k of KEYS) delete process.env[k];
}
function setKeys() {
  process.env.OKX_API_KEY = "test-key";
  process.env.OKX_API_SECRET = "test-secret";
  process.env.OKX_API_PASSPHRASE = "test-pass";
  process.env.VETO_PAYTO_ADDRESS = "0x1111111111111111111111111111111111111111";
}

beforeEach(() => {
  vi.resetModules();
});
afterEach(() => {
  clearKeys();
  vi.resetModules();
});

describe("x402 payment gate", () => {
  it("is OPEN (dev mode) when OKX keys are absent", async () => {
    clearKeys();
    const { paymentConfigured } = await import("../x402/facilitator");
    expect(paymentConfigured()).toBe(false);
  });

  it("ENFORCES payment once all four vars are set", async () => {
    setKeys();
    const { paymentConfigured } = await import("../x402/facilitator");
    expect(paymentConfigured()).toBe(true);
  });

  it("does NOT enforce with a payout address but no API keys", async () => {
    clearKeys();
    process.env.VETO_PAYTO_ADDRESS = "0x1111111111111111111111111111111111111111";
    const { paymentConfigured } = await import("../x402/facilitator");
    expect(paymentConfigured()).toBe(false);
  });

  it("prices every instrument, and the challenge carries the payout address", async () => {
    setKeys();
    const { requirementsFor } = await import("../x402/pricing");
    const endpoints = ["verdict", "approvals", "payload", "counterparty", "forensics"] as const;
    for (const e of endpoints) {
      const r = requirementsFor(e, `https://veto.dev/${e}`);
      expect(BigInt(r.amount)).toBeGreaterThan(0n);        // real price
      expect(r.network).toBe("eip155:196");                // paid on X Layer mainnet
      expect(r.payTo).toBe("0x1111111111111111111111111111111111111111");
      expect(r.scheme).toBe("exact");
    }
  });
});
