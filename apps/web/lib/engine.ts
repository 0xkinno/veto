// Client for the VETO engine. Base URL comes from NEXT_PUBLIC_ENGINE_URL so
// the deployed dashboard (Vercel) can point at the deployed engine (Railway).

export const ENGINE_URL =
  process.env.NEXT_PUBLIC_ENGINE_URL ?? "http://localhost:8787";

export type Verdict = "ALLOW" | "WARN" | "VETO";

export interface StoredVerdict {
  id: string;
  verdict: Verdict;
  policy: string;
  summary: string;
  agent: string;
  evidenceHash: string;
  attestationTx?: string;
  latencyMs: number;
  reasons: string[];
  at: number;
}

export interface Stats {
  total: number;
  allow: number;
  warn: number;
  veto: number;
  avgLatency: number;
  ruleTally: Record<string, number>;
}

export interface VerdictResponse {
  verdict: Verdict;
  reasons: string[];
  findings: unknown[];
  evidenceHash: string;
  attestationTx?: string;
  blockNumber: number;
  latencyMs: number;
  policy: string;
}

export async function getStats(): Promise<Stats | null> {
  try {
    const r = await fetch(`${ENGINE_URL}/stats`, { cache: "no-store" });
    if (!r.ok) return null;
    return (await r.json()) as Stats;
  } catch {
    return null;
  }
}

export async function getVerdicts(limit = 12): Promise<StoredVerdict[]> {
  try {
    const r = await fetch(`${ENGINE_URL}/verdicts?limit=${limit}`, {
      cache: "no-store",
    });
    if (!r.ok) return [];
    const data = (await r.json()) as { verdicts: StoredVerdict[] };
    return data.verdicts;
  } catch {
    return [];
  }
}

export interface DemoInput {
  from: string;
  to: string;
  data?: string;
  value?: string;
  summary: string;
  policy: "treasury-strict" | "standard" | "degen-loose";
}

export async function runDemoVerdict(
  input: DemoInput
): Promise<VerdictResponse> {
  const r = await fetch(`${ENGINE_URL}/demo/verdict`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      tx: {
        from: input.from,
        to: input.to,
        data: input.data || "0x",
        value: input.value || undefined,
        chainId: 196,
      },
      intent: { summary: input.summary },
      policy: input.policy,
    }),
  });
  if (!r.ok) {
    const text = await r.text();
    throw new Error(`Engine ${r.status}: ${text}`);
  }
  return (await r.json()) as VerdictResponse;
}
