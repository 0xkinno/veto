import { describe, it, expect } from "vitest";
import { extractEffects } from "../diff";
import { parseIntent } from "../intent";
import { aggregate } from "../rules";
import type { VerdictRequest, SimulationResult } from "../lib/types";
import type { DecodedLog } from "../simulator";

const CALLER = "0x1111111111111111111111111111111111111111";
const GOOD = "0x2222222222222222222222222222222222222222";
const EVIL = "0x3333333333333333333333333333333333333333";
const USDT = "0x4444444444444444444444444444444444444444";
const MAXISH =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";

function req(overrides: Partial<VerdictRequest> = {}): VerdictRequest {
  return {
    tx: { from: CALLER, to: GOOD, data: "0x", chainId: 196 },
    intent: { summary: "Swap 50 USDT for OKB" },
    policy: "standard",
    ...overrides,
  };
}

function sim(effects: SimulationResult["effects"]): SimulationResult {
  return { blockNumber: 100, reverted: false, effects, gasUsed: "21000" };
}

describe("diff extractor", () => {
  it("turns a Transfer log into transfer + balance effects", () => {
    const decoded: DecodedLog[] = [
      { event: "Transfer", token: USDT, from: CALLER, to: GOOD, value: "50", unlimited: false },
    ];
    const effects = extractEffects({ decoded, reverted: false });
    expect(effects.some((e) => e.kind === "transfer")).toBe(true);
    // caller nets -50, recipient +50
    const callerBal = effects.find((e) => e.kind === "balance" && e.account === CALLER.toLowerCase());
    expect(callerBal?.amount).toBe("-50");
  });

  it("emits a single revert effect on a reverted sim", () => {
    const effects = extractEffects({ decoded: [], reverted: true, revertReason: "ds-math-sub-underflow" });
    expect(effects).toHaveLength(1);
    expect(effects[0].kind).toBe("revert");
  });
});

describe("intent parser", () => {
  it("extracts recipients and out-token from free text", () => {
    const parsed = parseIntent(
      { summary: `send 50 USDT to ${GOOD}` },
      { from: CALLER, to: GOOD, data: "0x", chainId: 196 }
    );
    expect(parsed.expects?.recipients).toContain(GOOD.toLowerCase());
    expect(parsed.expects?.tokenOut?.token).toBe("USDT");
  });

  it("trusts caller-supplied structured expects", () => {
    const parsed = parseIntent(
      { summary: "x", expects: { recipients: [GOOD] } },
      { from: CALLER, to: GOOD, data: "0x", chainId: 196 }
    );
    expect(parsed.expects?.recipients).toEqual([GOOD]);
  });
});

describe("verdict aggregation", () => {
  it("ALLOWs a declared, clean transfer", () => {
    const r = req({ intent: { summary: "pay", expects: { recipients: [GOOD] } } });
    const s = sim([
      { kind: "transfer", token: USDT, from: CALLER.toLowerCase(), to: GOOD.toLowerCase(), amount: "50" },
    ]);
    const { verdict } = aggregate(s, r);
    expect(verdict).toBe("ALLOW");
  });

  it("VETOs an undeclared transfer to an unknown recipient", () => {
    const r = req({ intent: { summary: "pay", expects: { recipients: [GOOD] } } });
    const s = sim([
      { kind: "transfer", token: USDT, from: CALLER.toLowerCase(), to: EVIL.toLowerCase(), amount: "500" },
    ]);
    const { verdict, reasons } = aggregate(s, r);
    expect(verdict).toBe("VETO");
    expect(reasons.join(" ")).toMatch(/undeclared transfer/i);
  });

  it("VETOs an unlimited approval under treasury-strict", () => {
    const r = req({ policy: "treasury-strict", intent: { summary: "approve", expects: { approvals: [] } } });
    const s = sim([
      { kind: "approval", token: USDT, owner: CALLER.toLowerCase(), spender: EVIL.toLowerCase(), amount: MAXISH, unlimited: true },
    ]);
    const { verdict } = aggregate(s, r);
    expect(verdict).toBe("VETO");
  });

  it("WARNs on an unlimited approval under degen-loose", () => {
    const r = req({
      policy: "degen-loose",
      intent: { summary: "approve spender", expects: { approvals: [{ token: USDT, spender: EVIL }] } },
    });
    const s = sim([
      { kind: "approval", token: USDT, owner: CALLER.toLowerCase(), spender: EVIL.toLowerCase(), amount: MAXISH, unlimited: true },
    ]);
    const { verdict } = aggregate(s, r);
    expect(verdict).toBe("WARN");
  });

  it("VETOs a reverting transaction outright", () => {
    const s: SimulationResult = { blockNumber: 1, reverted: true, revertReason: "boom", effects: [{ kind: "revert", detail: "boom" }], gasUsed: "0" };
    const { verdict } = aggregate(s, req());
    expect(verdict).toBe("VETO");
  });
});
