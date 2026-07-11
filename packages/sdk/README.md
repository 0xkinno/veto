# @veto/sdk

Route every agent transaction through VETO before it is signed. A VETO
verdict refuses to sign; a WARN signs but reports. Ten lines to integrate.

## Install

```bash
npm install @veto/sdk
```

## guard(signer)

Wrap any ethers v6 signer. Every `sendTransaction` is ruled on first.

```ts
import { guard } from "@veto/sdk";

const signer = guard(agentSigner, {
  endpoint: "https://engine.veto.dev",
  policy: "treasury-strict",
  intent: (tx) => `agent task: ${tx.to}`,
  onVerdict: (v) => audit.log(v),
});

// a red verdict refuses to sign — by design
await signer.sendTransaction(tx);
// throws VetoRefused — "undeclared unlimited approval"
```

## check(tx, from)

A one-shot verdict without wrapping a signer.

```ts
import { check } from "@veto/sdk";

const v = await check(tx, agentAddress, { policy: "standard" });
if (v.verdict === "VETO") abort(v.reasons);
```

## Options

| Option       | Description                                                    |
| ------------ | -------------------------------------------------------------- |
| `endpoint`   | VETO engine base URL (default `http://localhost:8787`)         |
| `policy`     | `treasury-strict` \| `standard` \| `degen-loose`               |
| `intent`     | Natural-language intent, or a function `(tx) => string`        |
| `chainId`    | Chain declared to the engine (default `196`, X Layer)          |
| `strictWarn` | If true, WARN also refuses to sign (default false)             |
| `onVerdict`  | Fired on every verdict, ALLOW included                         |
| `paySettle`  | Produces the `X-PAYMENT` header when the engine returns 402    |

## Payment

When the engine enforces x402, a verdict call returns HTTP 402 with a
payment challenge. Supply `paySettle` to sign the payment authorization
(via your agent wallet / OKX payment SDK) and the SDK retries once:

```ts
const signer = guard(agentSigner, {
  paySettle: async (challenge) => wallet.signX402(challenge), // → base64 header
});
```

Without `paySettle`, a 402 throws `VetoPaymentRequired` carrying the challenge.

## Errors

- `VetoRefused` — the verdict was VETO (or WARN under `strictWarn`). Carries `.result`.
- `VetoPaymentRequired` — payment needed and unpaid. Carries `.challenge`.
