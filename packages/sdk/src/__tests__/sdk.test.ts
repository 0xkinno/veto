import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { guard, check, VetoRefused, VetoPaymentRequired } from "../index";

const FROM = "0x1111111111111111111111111111111111111111";

function mockFetchOnce(status: number, json: unknown) {
  return vi.fn().mockResolvedValue({
    status,
    ok: status >= 200 && status < 300,
    json: async () => json,
    text: async () => JSON.stringify(json),
  });
}

const fakeSigner = {
  getAddress: async () => FROM,
  sendTransaction: vi.fn(async (tx: unknown) => ({ hash: "0xsent", tx })),
};

beforeEach(() => {
  fakeSigner.sendTransaction.mockClear();
});
afterEach(() => {
  vi.unstubAllGlobals();
});

describe("check()", () => {
  it("returns the verdict from the engine", async () => {
    vi.stubGlobal("fetch", mockFetchOnce(200, {
      verdict: "ALLOW", reasons: [], evidenceHash: "0xabc",
    }));
    const r = await check({ to: "0x2", data: "0x" }, FROM);
    expect(r.verdict).toBe("ALLOW");
  });
});

describe("guard()", () => {
  it("signs when the verdict is ALLOW", async () => {
    vi.stubGlobal("fetch", mockFetchOnce(200, {
      verdict: "ALLOW", reasons: [], evidenceHash: "0xabc",
    }));
    const s = guard(fakeSigner);
    await s.sendTransaction({ to: "0x2", data: "0x" });
    expect(fakeSigner.sendTransaction).toHaveBeenCalledOnce();
  });

  it("refuses to sign on VETO", async () => {
    vi.stubGlobal("fetch", mockFetchOnce(200, {
      verdict: "VETO", reasons: ["undeclared transfer"], evidenceHash: "0xabc",
    }));
    const s = guard(fakeSigner);
    await expect(s.sendTransaction({ to: "0x2", data: "0x" })).rejects.toThrow(VetoRefused);
    expect(fakeSigner.sendTransaction).not.toHaveBeenCalled();
  });

  it("signs on WARN by default, refuses on strictWarn", async () => {
    vi.stubGlobal("fetch", mockFetchOnce(200, {
      verdict: "WARN", reasons: ["slippage high"], evidenceHash: "0xabc",
    }));
    const lenient = guard(fakeSigner);
    await lenient.sendTransaction({ to: "0x2", data: "0x" });
    expect(fakeSigner.sendTransaction).toHaveBeenCalledOnce();

    vi.stubGlobal("fetch", mockFetchOnce(200, {
      verdict: "WARN", reasons: ["slippage high"], evidenceHash: "0xabc",
    }));
    const strict = guard(fakeSigner, { strictWarn: true });
    await expect(strict.sendTransaction({ to: "0x2", data: "0x" })).rejects.toThrow(VetoRefused);
  });

  it("fires onVerdict for every ruling", async () => {
    vi.stubGlobal("fetch", mockFetchOnce(200, {
      verdict: "ALLOW", reasons: [], evidenceHash: "0xabc",
    }));
    const seen: string[] = [];
    const s = guard(fakeSigner, { onVerdict: (v) => seen.push(v.verdict) });
    await s.sendTransaction({ to: "0x2", data: "0x" });
    expect(seen).toEqual(["ALLOW"]);
  });
});

describe("x402 payment", () => {
  it("throws VetoPaymentRequired when 402 and no paySettle", async () => {
    vi.stubGlobal("fetch", mockFetchOnce(402, {
      x402Version: 2, accepts: [{ scheme: "exact", network: "eip155:196", amount: "150000", asset: "0x", payTo: "0x" }],
    }));
    await expect(check({ to: "0x2" }, FROM)).rejects.toThrow(VetoPaymentRequired);
  });

  it("pays via paySettle then retries and succeeds", async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce({
        status: 402, ok: false,
        json: async () => ({ x402Version: 2, accepts: [{ scheme: "exact", network: "eip155:196", amount: "150000", asset: "0x", payTo: "0x" }] }),
        text: async () => "",
      })
      .mockResolvedValueOnce({
        status: 200, ok: true,
        json: async () => ({ verdict: "ALLOW", reasons: [], evidenceHash: "0xabc" }),
        text: async () => "",
      });
    vi.stubGlobal("fetch", fetchMock);

    const paySettle = vi.fn(async () => "base64xpayment");
    const r = await check({ to: "0x2" }, FROM, { paySettle });
    expect(paySettle).toHaveBeenCalledOnce();
    expect(r.verdict).toBe("ALLOW");
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });
});
