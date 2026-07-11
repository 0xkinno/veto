import { describe, it, expect } from "vitest";
import { demoEffects } from "../lib/demo-scenarios";
import { aggregate } from "../rules";
import type { VerdictRequest, SimulationResult } from "../lib/types";

const CALLER = "0x1111111111111111111111111111111111111111";
const SPENDER = "0x7f9000000000000000000000000000000000dc41";
const RECIP = "0x2222222222222222222222222222222222222222";

function simFrom(effects: SimulationResult["effects"]): SimulationResult {
  return { blockNumber: 1, reverted: false, effects, gasUsed: "0" };
}

describe("demo presets rule as labelled", () => {
  it("Undeclared approval preset → VETO", () => {
    const req: VerdictRequest = {
      tx: { from: CALLER, to: SPENDER, data: "0x095ea7b3", chainId: 196 },
      intent: { summary: "Swap 50 USDT for OKB" },
      policy: "treasury-strict",
    };
    const effects = demoEffects(req);
    expect(effects).not.toBeNull();
    const { verdict } = aggregate(simFrom(effects!), req);
    expect(verdict).toBe("VETO");
  });

  it("Clean swap preset (declared recipient) → ALLOW", () => {
    const req: VerdictRequest = {
      tx: { from: CALLER, to: RECIP, data: "0x", chainId: 196 },
      intent: {
        summary: "Swap 50 USDT for OKB",
        expects: { recipients: [RECIP] },
      },
      policy: "standard",
    };
    const effects = demoEffects(req);
    expect(effects).not.toBeNull();
    const { verdict } = aggregate(simFrom(effects!), req);
    expect(verdict).toBe("ALLOW");
  });

  it("custom tx (not a preset) → null, uses live simulator", () => {
    const req: VerdictRequest = {
      tx: { from: CALLER, to: RECIP, data: "0xdeadbeef", chainId: 196 },
      intent: { summary: "custom" },
      policy: "standard",
    };
    expect(demoEffects(req)).toBeNull();
  });
});
