import { isKnownDrainer } from "../lib/registries";
import { isContract } from "../lib/chain";
import type { Verdict } from "../lib/types";

/**
 * /payload — Task-payload screening.
 *
 * Answers: "Is this inbound job trying to inject or drain?"
 *
 * An agent on a marketplace receives work from strangers. Before it accepts,
 * VETO screens the payload itself: prompt injection, credential extraction,
 * embedded approval calldata, drainer addresses, urgency coercion.
 *
 * The work is judged before the worker is exposed to it.
 */

export interface PayloadFinding {
  category: string;
  severity: Verdict;
  message: string;
  evidence?: string;
}

export interface PayloadReport {
  verdict: Verdict;
  riskScore: number; // 0-100
  findings: PayloadFinding[];
  addressesFound: string[];
  summary: string;
}

const APPROVE_SELECTOR = "0x095ea7b3";
const TRANSFER_FROM_SELECTOR = "0x23b872dd";
const SET_APPROVAL_FOR_ALL = "0xa22cb465";
const PERMIT_SELECTOR = "0xd505accf";

interface Pattern {
  category: string;
  severity: Verdict;
  re: RegExp;
  message: string;
}

/** Prompt-injection and social-engineering patterns. */
const PATTERNS: Pattern[] = [
  {
    category: "prompt-injection",
    severity: "VETO",
    re: /\b(ignore|disregard|forget|override)\b[^.]{0,40}\b(previous|prior|earlier|above|all)\b[^.]{0,20}\b(instruction|prompt|rule|direction|system)/i,
    message: "Attempts to override the agent's prior instructions.",
  },
  {
    category: "prompt-injection",
    severity: "VETO",
    re: /\b(you are now|act as|pretend to be|new system prompt|system:)\b/i,
    message: "Attempts to reassign the agent's role or system prompt.",
  },
  {
    category: "credential-extraction",
    severity: "VETO",
    re: /\b(private key|seed phrase|mnemonic|secret key|recovery phrase|api[_ -]?key|passphrase)\b/i,
    message: "Requests credentials. No legitimate task ever needs these.",
  },
  {
    category: "credential-extraction",
    severity: "VETO",
    re: /\b(export|reveal|share|send|paste|show)\b[^.]{0,30}\b(wallet|key|seed|credential)/i,
    message: "Attempts to extract wallet material.",
  },
  {
    category: "unbounded-approval",
    severity: "VETO",
    re: /\b(unlimited|infinite|max(imum)?|unrestricted)\b[^.]{0,25}\b(approv|allowance|spend)/i,
    message: "Instructs the agent to grant an unbounded allowance.",
  },
  {
    category: "coercion",
    severity: "WARN",
    re: /\b(urgent|immediately|right now|do not verify|skip (the )?(check|verification|review)|no time|hurry)\b/i,
    message: "Urgency language designed to bypass verification.",
  },
  {
    category: "exfiltration",
    severity: "WARN",
    re: /\b(send|post|forward|upload)\b[^.]{0,30}\b(to|at)\b\s*https?:\/\//i,
    message: "Instructs the agent to send data to an external endpoint.",
  },
  {
    category: "obfuscation",
    severity: "WARN",
    re: /\b(base64|hex[- ]?encoded|decode this|eval\(|atob\()/i,
    message: "Encoded or obfuscated content the agent is asked to execute.",
  },
];

export async function screenPayload(raw: unknown): Promise<PayloadReport> {
  const text = typeof raw === "string" ? raw : JSON.stringify(raw ?? "");
  const findings: PayloadFinding[] = [];

  // --- 1. language + injection patterns ---------------------------------
  for (const p of PATTERNS) {
    const m = text.match(p.re);
    if (m) {
      findings.push({
        category: p.category,
        severity: p.severity,
        message: p.message,
        evidence: m[0].slice(0, 90),
      });
    }
  }

  // --- 2. embedded calldata ---------------------------------------------
  const selectors: [string, string, Verdict][] = [
    [APPROVE_SELECTOR, "Embedded ERC20 approve() calldata.", "VETO"],
    [SET_APPROVAL_FOR_ALL, "Embedded setApprovalForAll() — grants an entire NFT collection.", "VETO"],
    [PERMIT_SELECTOR, "Embedded permit() — a gasless allowance signature.", "VETO"],
    [TRANSFER_FROM_SELECTOR, "Embedded transferFrom() — moves funds the agent already approved.", "WARN"],
  ];
  const lower = text.toLowerCase();
  for (const [sel, msg, sev] of selectors) {
    if (lower.includes(sel)) {
      findings.push({
        category: "embedded-calldata",
        severity: sev,
        message: msg,
        evidence: sel,
      });
    }
  }

  // --- 3. addresses in the payload --------------------------------------
  const addresses = [...new Set((text.match(/0x[a-fA-F0-9]{40}/g) ?? []).map((a) => a.toLowerCase()))];

  for (const addr of addresses) {
    if (isKnownDrainer(addr)) {
      findings.push({
        category: "drainer-address",
        severity: "VETO",
        message: `Payload references a known drainer: ${addr.slice(0, 8)}…`,
        evidence: addr,
      });
      continue;
    }
    // an EOA recipient in a task payload is a common drain shape
    try {
      const contract = await isContract(addr);
      if (!contract) {
        findings.push({
          category: "recipient-shape",
          severity: "WARN",
          message: `Payload names an externally owned account (${addr.slice(0, 8)}…), not a contract.`,
          evidence: addr,
        });
      }
    } catch {
      /* chain unavailable — the language findings still stand */
    }
  }

  // --- verdict ------------------------------------------------------------
  const hasVeto = findings.some((f) => f.severity === "VETO");
  const warns = findings.filter((f) => f.severity === "WARN").length;
  const vetos = findings.filter((f) => f.severity === "VETO").length;

  const verdict: Verdict = hasVeto ? "VETO" : warns > 0 ? "WARN" : "ALLOW";
  const riskScore = Math.min(100, vetos * 40 + warns * 15);

  const summary =
    verdict === "VETO"
      ? "Reject this task. The payload is attempting to compromise the agent."
      : verdict === "WARN"
      ? "Accept only with hardened policy. The payload shows manipulation patterns."
      : "No injection, drain, or extraction pattern detected.";

  return { verdict, riskScore, findings, addressesFound: addresses, summary };
}
