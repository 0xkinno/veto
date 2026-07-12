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


// ---- the four other instruments ---------------------------------------

export interface ApprovalFinding {
  token: string; symbol: string; spender: string; allowance: string;
  unlimited: boolean; spenderIsContract: boolean; knownDrainer: boolean;
  risk: Verdict; reason: string;
  revoke: { to: string; data: string; value: string };
}
export interface ApprovalsReport {
  wallet: string; scanned: number; live: number; atRisk: number;
  critical: number; exposureScore: number; findings: ApprovalFinding[];
}

export interface PayloadFinding {
  category: string; severity: Verdict; message: string; evidence?: string;
}
export interface PayloadReport {
  verdict: Verdict; riskScore: number; findings: PayloadFinding[];
  addressesFound: string[]; summary: string;
}

export interface Signal { name: string; value: string; weight: number; note: string }
export interface CounterpartyReport {
  address: string; type: "contract" | "eoa";
  grade: "TRUSTED" | "NEUTRAL" | "CAUTION" | "AVOID";
  trustScore: number; signals: Signal[]; summary: string;
  onChain: { isContract: boolean; codeSizeBytes: number; nativeBalanceWei: string; outgoingTxCount: number };
}

export interface ForensicsReport {
  txHash: string; blockNumber: number; from: string; to: string | null;
  status: "success" | "reverted"; policy: string;
  wouldHaveRuled: Verdict; reasons: string[]; evidenceHash: string; postMortem: string;
}

async function post<T>(path: string, body: unknown): Promise<T> {
  const r = await fetch(`${ENGINE_URL}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await r.json();
  if (!r.ok || (data as { error?: string }).error) {
    throw new Error((data as { message?: string; error?: string }).message ?? (data as { error?: string }).error ?? `Engine ${r.status}`);
  }
  return data as T;
}

export const scanApprovals = (wallet: string) =>
  post<ApprovalsReport>("/demo/approvals", { wallet });

export const screenPayload = (payload: string) =>
  post<PayloadReport>("/demo/payload", { payload });

export const checkCounterparty = (address: string) =>
  post<CounterpartyReport>("/demo/counterparty", { address });

export const runForensics = (txHash: string, policy = "standard") =>
  post<ForensicsReport>("/demo/forensics", { txHash, policy });
