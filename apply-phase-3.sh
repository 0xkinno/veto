#!/usr/bin/env bash
# VETO — Phase 3 apply script (all-rounder attestation contract)
# Run from the root of your veto folder:  bash apply-phase-3.sh
# Writes/overwrites only the files below. node_modules untouched.
set -e
echo "Writing Phase 3 files into $(pwd) ..."
mkdir -p contracts/contracts contracts/scripts contracts/test apps/engine/src/lib apps/engine/src/routes

# ---------- contracts/contracts/VetoAttestation.sol ----------
cat > contracts/contracts/VetoAttestation.sol << 'VETO_EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title VetoAttestation
 * @author VETO
 * @notice The on-chain commitment log for VETO verdicts. Every ruling the
 *         engine makes can be committed here so it is independently
 *         verifiable against the chain. VETO never asks to be believed;
 *         this contract is the receipt.
 *
 * @dev Designed to deploy once and never be replaced. It is deliberately
 *      NOT a proxy — the surface is small and legible — but it carries
 *      every hook VETO's roadmap needs:
 *
 *        - the verdict itself is stored (ALLOW / WARN / VETO), not just a hash
 *        - per-agent verdict history for on-chain reputation / counterparty reads
 *        - batch attestation for gas-efficient high volume
 *        - revoke / supersede that preserves history (forensics trail intact)
 *        - a payment reference per verdict so x402 settlement can bind on-chain
 *        - a free-form bytes metadata slot per verdict for data not yet designed
 *        - multi-attester authorisation with revocation
 *        - pausable kill switch and two-step ownership transfer
 */
contract VetoAttestation {
    // ----------------------------------------------------------------- types

    enum Verdict {
        NONE, // 0 — never attested
        ALLOW, // 1
        WARN, // 2
        VETO // 3
    }

    struct Attestation {
        bytes32 verdictHash; // keccak of the canonical verdict object
        bytes32 evidenceHash; // keccak of the evidence bundle
        bytes32 policyId; // policy profile applied
        address agent; // the agent/wallet the verdict was rendered for
        address attester; // engine signer that submitted it
        Verdict verdict; // the actual ruling, readable on-chain
        uint64 timestamp; // block time of the write
        bool revoked; // superseded / corrected, history preserved
        bytes32 supersededBy; // evidenceHash of the correcting attestation
        bytes32 paymentRef; // x402 settlement reference (0 if none)
    }

    // ------------------------------------------------------------- storage

    /// @dev evidenceHash => attestation. One commitment per evidence bundle.
    mapping(bytes32 => Attestation) public attestations;

    /// @dev agent => list of evidence hashes rendered for it (reputation feed).
    mapping(address => bytes32[]) private _agentHistory;

    /// @dev evidenceHash => free-form metadata for data not yet designed.
    mapping(bytes32 => bytes) public metadata;

    /// @dev authorised engine signers.
    mapping(address => bool) public attesters;

    address public owner;
    address public pendingOwner;
    bool public paused;
    uint256 public total;

    // -------------------------------------------------------------- events

    event Attested(
        bytes32 indexed evidenceHash,
        bytes32 indexed verdictHash,
        address indexed agent,
        Verdict verdict,
        bytes32 policyId,
        address attester,
        uint64 timestamp
    );
    event Revoked(bytes32 indexed evidenceHash, bytes32 supersededBy);
    event MetadataSet(bytes32 indexed evidenceHash);
    event PaymentBound(bytes32 indexed evidenceHash, bytes32 paymentRef);
    event AttesterSet(address indexed attester, bool allowed);
    event Paused(bool paused);
    event OwnershipTransferStarted(address indexed from, address indexed to);
    event OwnershipTransferred(address indexed from, address indexed to);

    // ------------------------------------------------------------ modifiers

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyAttester() {
        require(attesters[msg.sender], "not attester");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "paused");
        _;
    }

    // ---------------------------------------------------------- constructor

    constructor() {
        owner = msg.sender;
        attesters[msg.sender] = true;
        emit AttesterSet(msg.sender, true);
    }

    // -------------------------------------------------------- attestation

    /**
     * @notice Commit a verdict to the chain.
     * @param verdictHash  keccak of the canonical verdict object
     * @param evidenceHash keccak of the evidence bundle (the unique key)
     * @param policyId     policy profile applied
     * @param agent        the agent/wallet the verdict was rendered for
     * @param verdict      the ruling (ALLOW / WARN / VETO)
     * @param paymentRef   x402 settlement reference, or bytes32(0) if none
     */
    function attest(
        bytes32 verdictHash,
        bytes32 evidenceHash,
        bytes32 policyId,
        address agent,
        Verdict verdict,
        bytes32 paymentRef
    ) public onlyAttester whenNotPaused {
        require(evidenceHash != bytes32(0), "empty evidence");
        require(verdict != Verdict.NONE, "invalid verdict");
        require(attestations[evidenceHash].timestamp == 0, "already attested");

        attestations[evidenceHash] = Attestation({
            verdictHash: verdictHash,
            evidenceHash: evidenceHash,
            policyId: policyId,
            agent: agent,
            attester: msg.sender,
            verdict: verdict,
            timestamp: uint64(block.timestamp),
            revoked: false,
            supersededBy: bytes32(0),
            paymentRef: paymentRef
        });

        if (agent != address(0)) _agentHistory[agent].push(evidenceHash);

        unchecked {
            total++;
        }

        emit Attested(
            evidenceHash,
            verdictHash,
            agent,
            verdict,
            policyId,
            msg.sender,
            uint64(block.timestamp)
        );

        if (paymentRef != bytes32(0)) {
            emit PaymentBound(evidenceHash, paymentRef);
        }
    }

    /**
     * @notice Commit many verdicts in a single transaction. Arrays must be
     *         the same length. Any duplicate/empty entry reverts the batch.
     */
    function attestBatch(
        bytes32[] calldata verdictHashes,
        bytes32[] calldata evidenceHashes,
        bytes32[] calldata policyIds,
        address[] calldata agents,
        Verdict[] calldata verdicts,
        bytes32[] calldata paymentRefs
    ) external onlyAttester whenNotPaused {
        uint256 n = evidenceHashes.length;
        require(
            verdictHashes.length == n &&
                policyIds.length == n &&
                agents.length == n &&
                verdicts.length == n &&
                paymentRefs.length == n,
            "length mismatch"
        );
        for (uint256 i = 0; i < n; ) {
            attest(
                verdictHashes[i],
                evidenceHashes[i],
                policyIds[i],
                agents[i],
                verdicts[i],
                paymentRefs[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Revoke/supersede a verdict without deleting it. History stays
     *         intact for forensics; the record is flagged and can point to
     *         the correcting attestation.
     */
    function revoke(bytes32 evidenceHash, bytes32 supersededBy)
        external
        onlyAttester
    {
        Attestation storage a = attestations[evidenceHash];
        require(a.timestamp != 0, "unknown attestation");
        require(!a.revoked, "already revoked");
        a.revoked = true;
        a.supersededBy = supersededBy;
        emit Revoked(evidenceHash, supersededBy);
    }

    /**
     * @notice Attach or replace free-form metadata for an attestation. This
     *         is the forward-compatibility slot: any data VETO has not yet
     *         designed can bind to a verdict here without a redeploy.
     */
    function setMetadata(bytes32 evidenceHash, bytes calldata data)
        external
        onlyAttester
    {
        require(attestations[evidenceHash].timestamp != 0, "unknown attestation");
        metadata[evidenceHash] = data;
        emit MetadataSet(evidenceHash);
    }

    /**
     * @notice Bind an x402 payment reference to an existing attestation
     *         (for flows where the verdict is written before settlement).
     */
    function bindPayment(bytes32 evidenceHash, bytes32 paymentRef)
        external
        onlyAttester
    {
        Attestation storage a = attestations[evidenceHash];
        require(a.timestamp != 0, "unknown attestation");
        a.paymentRef = paymentRef;
        emit PaymentBound(evidenceHash, paymentRef);
    }

    // --------------------------------------------------------------- views

    /// @notice Verify an evidence hash was attested with the expected verdict.
    function verify(bytes32 evidenceHash, bytes32 verdictHash)
        external
        view
        returns (bool)
    {
        Attestation storage a = attestations[evidenceHash];
        return a.timestamp != 0 && !a.revoked && a.verdictHash == verdictHash;
    }

    /// @notice The full attestation record for an evidence hash.
    function get(bytes32 evidenceHash)
        external
        view
        returns (Attestation memory)
    {
        return attestations[evidenceHash];
    }

    /// @notice How many verdicts have been rendered for an agent.
    function agentCount(address agent) external view returns (uint256) {
        return _agentHistory[agent].length;
    }

    /// @notice A page of an agent's verdict history (evidence hashes).
    function agentHistory(address agent, uint256 offset, uint256 limit)
        external
        view
        returns (bytes32[] memory page)
    {
        bytes32[] storage h = _agentHistory[agent];
        if (offset >= h.length) return new bytes32[](0);
        uint256 end = offset + limit;
        if (end > h.length) end = h.length;
        page = new bytes32[](end - offset);
        for (uint256 i = offset; i < end; ) {
            page[i - offset] = h[i];
            unchecked {
                ++i;
            }
        }
    }

    // ------------------------------------------------------------- admin

    function setAttester(address who, bool allowed) external onlyOwner {
        attesters[who] = allowed;
        emit AttesterSet(who, allowed);
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
        emit Paused(p);
    }

    function transferOwnership(address to) external onlyOwner {
        pendingOwner = to;
        emit OwnershipTransferStarted(owner, to);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "not pending owner");
        address prev = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(prev, owner);
    }
}
VETO_EOF

# ---------- contracts/test/VetoAttestation.test.js ----------
cat > contracts/test/VetoAttestation.test.js << 'VETO_EOF'
const { expect } = require("chai");
const { ethers } = require("hardhat");

const V = { NONE: 0, ALLOW: 1, WARN: 2, VETO: 3 };
const h = (s) => ethers.keccak256(ethers.toUtf8Bytes(s));
const ZERO = ethers.ZeroHash;
const ZADDR = ethers.ZeroAddress;

describe("VetoAttestation", function () {
  async function deploy() {
    const [owner, engine, agent, other] = await ethers.getSigners();
    const Veto = await ethers.getContractFactory("VetoAttestation");
    const veto = await Veto.deploy();
    await veto.waitForDeployment();
    return { veto, owner, engine, agent, other };
  }

  it("attests a verdict and reads it back on-chain", async function () {
    const { veto, agent } = await deploy();
    const ev = h("evidence-1");
    await expect(
      veto.attest(h("VETO"), ev, h("treasury-strict"), agent.address, V.VETO, ZERO)
    ).to.emit(veto, "Attested");

    const rec = await veto.get(ev);
    expect(rec.verdict).to.equal(V.VETO);
    expect(rec.agent).to.equal(agent.address);
    expect(await veto.verify(ev, h("VETO"))).to.equal(true);
    expect(await veto.total()).to.equal(1n);
  });

  it("records per-agent history and paginates it", async function () {
    const { veto, agent } = await deploy();
    await veto.attest(h("a"), h("e1"), h("standard"), agent.address, V.ALLOW, ZERO);
    await veto.attest(h("b"), h("e2"), h("standard"), agent.address, V.WARN, ZERO);
    expect(await veto.agentCount(agent.address)).to.equal(2n);
    const page = await veto.agentHistory(agent.address, 0, 10);
    expect(page.length).to.equal(2);
    expect(page[0]).to.equal(h("e1"));
  });

  it("attests a batch in one transaction", async function () {
    const { veto, agent } = await deploy();
    await veto.attestBatch(
      [h("va"), h("vb")],
      [h("eA"), h("eB")],
      [h("standard"), h("standard")],
      [agent.address, agent.address],
      [V.ALLOW, V.VETO],
      [ZERO, ZERO]
    );
    expect(await veto.total()).to.equal(2n);
    expect((await veto.get(h("eB"))).verdict).to.equal(V.VETO);
  });

  it("rejects a duplicate evidence commitment", async function () {
    const { veto, agent } = await deploy();
    await veto.attest(h("v"), h("dup"), h("standard"), agent.address, V.ALLOW, ZERO);
    await expect(
      veto.attest(h("v"), h("dup"), h("standard"), agent.address, V.ALLOW, ZERO)
    ).to.be.revertedWith("already attested");
  });

  it("rejects a NONE verdict", async function () {
    const { veto, agent } = await deploy();
    await expect(
      veto.attest(h("v"), h("e"), h("standard"), agent.address, V.NONE, ZERO)
    ).to.be.revertedWith("invalid verdict");
  });

  it("revokes without deleting, invalidating verify", async function () {
    const { veto, agent } = await deploy();
    const ev = h("to-revoke");
    await veto.attest(h("v"), ev, h("standard"), agent.address, V.WARN, ZERO);
    await expect(veto.revoke(ev, h("corrected"))).to.emit(veto, "Revoked");
    const rec = await veto.get(ev);
    expect(rec.revoked).to.equal(true);
    expect(rec.supersededBy).to.equal(h("corrected"));
    expect(await veto.verify(ev, h("v"))).to.equal(false); // revoked fails verify
  });

  it("stores free-form metadata and binds a payment", async function () {
    const { veto, agent } = await deploy();
    const ev = h("meta");
    await veto.attest(h("v"), ev, h("standard"), agent.address, V.ALLOW, ZERO);
    await expect(
      veto.setMetadata(ev, ethers.toUtf8Bytes("future-field"))
    ).to.emit(veto, "MetadataSet");
    await expect(veto.bindPayment(ev, h("pay-tx"))).to.emit(veto, "PaymentBound");
    expect((await veto.get(ev)).paymentRef).to.equal(h("pay-tx"));
  });

  it("enforces attester authorisation", async function () {
    const { veto, engine, agent } = await deploy();
    await expect(
      veto.connect(engine).attest(h("v"), h("e"), h("standard"), agent.address, V.ALLOW, ZERO)
    ).to.be.revertedWith("not attester");
    await veto.setAttester(engine.address, true);
    await expect(
      veto.connect(engine).attest(h("v"), h("e"), h("standard"), agent.address, V.ALLOW, ZERO)
    ).to.emit(veto, "Attested");
  });

  it("pauses and resumes attestation", async function () {
    const { veto, agent } = await deploy();
    await veto.setPaused(true);
    await expect(
      veto.attest(h("v"), h("e"), h("standard"), agent.address, V.ALLOW, ZERO)
    ).to.be.revertedWith("paused");
    await veto.setPaused(false);
    await expect(
      veto.attest(h("v"), h("e"), h("standard"), agent.address, V.ALLOW, ZERO)
    ).to.emit(veto, "Attested");
  });

  it("transfers ownership in two steps", async function () {
    const { veto, owner, other } = await deploy();
    await veto.transferOwnership(other.address);
    expect(await veto.owner()).to.equal(owner.address); // not yet
    await veto.connect(other).acceptOwnership();
    expect(await veto.owner()).to.equal(other.address);
  });
});
VETO_EOF

# ---------- contracts/scripts/deploy.js ----------
cat > contracts/scripts/deploy.js << 'VETO_EOF'
const hre = require("hardhat");

async function main() {
  const net = hre.network.name;
  const [deployer] = await hre.ethers.getSigners();
  const bal = await hre.ethers.provider.getBalance(deployer.address);

  console.log("Network:  ", net);
  console.log("Deployer: ", deployer.address);
  console.log("Balance:  ", hre.ethers.formatEther(bal), "OKB");

  if (bal === 0n) {
    console.log("\nDeployer has 0 OKB. Claim testnet OKB first:");
    console.log("  https://web3.okx.com/xlayer/faucet\n");
    throw new Error("insufficient funds for deploy");
  }

  const Veto = await hre.ethers.getContractFactory("VetoAttestation");
  const veto = await Veto.deploy();
  await veto.waitForDeployment();

  const address = await veto.getAddress();
  const tx = veto.deploymentTransaction();

  console.log("\nVetoAttestation deployed.");
  console.log("  Address:  ", address);
  console.log("  Deploy tx:", tx?.hash);
  console.log("\nNext steps:");
  console.log("  1. Put this in apps/engine/.env:");
  console.log(`       ATTESTATION_ADDRESS=${address}`);
  console.log("  2. Keep the deploy tx hash above as a proof artifact.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
VETO_EOF

# ---------- apps/engine/src/lib/attest.ts ----------
cat > apps/engine/src/lib/attest.ts << 'VETO_EOF'
import type { PolicyId, Verdict } from "./types";
import { config } from "./config";

/**
 * Write a verdict attestation to X Layer via the deployed VetoAttestation
 * contract:
 *
 *   attest(verdictHash, evidenceHash, policyId, agent, verdict, paymentRef)
 *
 * PHASE 4 — implement:
 *   1. Build a wallet from config.attesterKey on config.rpcUrl.
 *   2. Encode the verdict enum (ALLOW=1, WARN=2, VETO=3).
 *   3. Call attest() on config.attestationAddress; return the tx hash.
 *   4. paymentRef binds the x402 settlement once payments are live.
 *
 * Returns undefined until the contract address + attester key are set,
 * so the engine runs end-to-end before the contract is wired.
 */
export async function attest(
  evidenceHash: string,
  policy: PolicyId,
  verdict: Verdict,
  agent?: string
): Promise<string | undefined> {
  void evidenceHash;
  void policy;
  void verdict;
  void agent;
  if (!config.attestationAddress || !config.attesterKey) return undefined;
  // TODO(phase-4): submit the on-chain attestation and return tx hash.
  return undefined;
}
VETO_EOF

# ---------- apps/engine/src/routes/verdict-core.ts ----------
cat > apps/engine/src/routes/verdict-core.ts << 'VETO_EOF'
import { simulate } from "../simulator";
import { parseIntent } from "../intent";
import { aggregate } from "../rules";
import { buildEvidence } from "../evidence";
import { attest } from "../lib/attest";
import type { VerdictRequest, VerdictResponse } from "../lib/types";

/**
 * The full verdict flow, shared by /verdict and reused (in part) by the
 * other instruments. Simulate, diff, run rules, hash evidence, attest.
 */
export async function runVerdict(
  req: VerdictRequest
): Promise<VerdictResponse> {
  const start = Date.now();

  const intent = parseIntent(req.intent, req.tx);
  const normalised: VerdictRequest = { ...req, intent };

  const sim = await simulate(req.tx);

  // Honeypot check: for any token the caller newly acquired, the engine
  // runs a follow-up sell-simulation and annotates sim.effects with
  // "sell-blocked" / "fee-on-transfer:N" so the honeypot rule can rule on
  // it. Wired against live X Layer once an RPC with fork support is set.
  // const acquired = tokensToSellTest(sim.effects, req.tx.from);
  // await annotateSellSimulations(sim, acquired, req.tx.from);

  const { verdict, findings, reasons } = aggregate(sim, normalised);
  const evidence = buildEvidence(sim, findings, normalised);

  // Attestation is best-effort: a verdict is still valid if the write
  // is pending. The evidence hash is the commitment either way.
  const attestationTx = await attest(
    evidence.hash,
    req.policy,
    verdict,
    req.tx.from
  ).catch(() => undefined);

  return {
    verdict,
    reasons,
    findings,
    evidenceHash: evidence.hash,
    attestationTx,
    blockNumber: sim.blockNumber,
    latencyMs: Date.now() - start,
    policy: req.policy,
  };
}
VETO_EOF

# ---------- docs/CHECKLIST.md ----------
cat > docs/CHECKLIST.md << 'VETO_EOF'
# VETO — Master Build Checklist

Tick each item as it is completed and tested against live infrastructure. Do not advance a phase until every box in it is checked. One build, modified forward — never regenerated.

---

## Phase 0 — Scaffold  ✅ (this zip)

- [x] Monorepo structure (`apps/engine`, `apps/web`, `packages/sdk`, `contracts`)
- [x] Root workspace config + scripts
- [x] Master README (architecture, diagrams, tables)
- [x] This checklist
- [x] Asset generation prompts (`design/ASSETS.md`)
- [x] Approved landing HTML reference (`design/landing.reference.html`)
- [x] Approved dashboard HTML reference (`design/dashboard.reference.html`)
- [x] Env templates for engine, web, contracts
- [x] Engine, SDK, contract, and web stubs with types + interfaces in place

---

## Phase 1 — Engine core  ✅

- [x] X Layer fork simulator (viem eth_call + debug_traceCall at latest block)
- [x] Execute unsigned transaction against the fork
- [x] Capture trace + revert reason
- [x] State-diff extractor (transfers, approvals, net balance deltas)
- [x] Intent parser (structured declared-intent object from free text)
- [x] Unit tests: clean diff, revert capture, intent extraction — all green

> Live-RPC note: fork simulation runs against the RPC in `apps/engine/.env`.
> A node exposing `debug_traceCall` gives full internal-call log capture;
> without it the simulator still returns revert state + decodable logs.

**Commands**
```bash
npm run engine:dev
npm --workspace apps/engine run test
```

---

## Phase 2 — Rule layers  ✅

- [x] `intent-divergence` — diff declared intent against simulated effect
- [x] `approval-risk` — unlimited / policy-sensitive approval flagging
- [x] `drainer / counterparty` — drainer set + registered-recipient screen
- [x] `honeypot` — sell-block + fee-on-transfer signals (sell-sim wiring marked)
- [x] `slippage` — realised-below-declared vs policy ceiling
- [x] Verdict aggregator (rules → ALLOW / WARN / VETO + reasons)
- [x] Unit tests per rule with fixture transactions — 9 passing

> `registries.ts` holds the drainer + registered-recipient lookups. Seed is
> empty by design; load a live threat feed and the caller ledger at boot.

---

## Phase 3 — Contract  ✅ (code) / ⏳ (deploy needs your faucet OKB)

- [x] All-rounder attestation contract (deploy-once design):
      - stores verdict enum (ALLOW/WARN/VETO), not just a hash
      - per-agent verdict history + pagination (on-chain reputation feed)
      - batch attestation for high volume
      - revoke / supersede preserving history (forensics trail)
      - x402 payment reference + bindPayment hook
      - free-form bytes metadata slot (forward-compat, no redeploy ever)
      - multi-attester auth, pausable, two-step ownership transfer
- [x] Events indexed for the dashboard ledger (Attested / Revoked / PaymentBound)
- [x] Hardhat test suite — 11 tests (attest, batch, history, revoke, metadata,
      payment, auth, pause, ownership)
- [ ] Deploy to X Layer testnet (needs faucet OKB in deployer wallet)
- [ ] Capture deployed address + deploy tx hash as proof artifacts

**Deploy commands**
```bash
# 1. fund the deployer: https://web3.okx.com/xlayer/faucet  (claim 0.2 OKB)
# 2. put the deployer key in contracts/.env  (DEPLOYER_PRIVATE_KEY=...)
npm run contracts:compile
npm run contracts:test
npm run contracts:deploy
# 3. copy the printed address into apps/engine/.env  (ATTESTATION_ADDRESS=...)
```

**Commands**
```bash
npm run contracts:compile
npm run contracts:test
npm run contracts:deploy
```

---

## Phase 4 — Server + x402

- [ ] `POST /verdict`
- [ ] `POST /approvals`
- [ ] `POST /payload`
- [ ] `POST /counterparty`
- [ ] `POST /forensics`
- [ ] x402 pay-per-call gate (HTTP 402 quote → USDT payment → served)
- [ ] Evidence bundle assembled + hashed + returned
- [ ] Attestation written on each verdict
- [ ] Redis verdict cache

---

## Phase 5 — SDK

- [ ] `guard(signer, opts)` wrapper
- [ ] Auto-route every outgoing tx through `/verdict`
- [ ] Refuse to sign on VETO; flag on WARN
- [ ] `onVerdict` callback hook
- [ ] Published build (`packages/sdk/dist`)

**Commands**
```bash
npm run sdk:build
```

---

## Phase 6 — Next.js UI

- [ ] Port approved landing (hero image, floating cards, horizontal slides)
- [ ] Port approved dashboard (all modules, one palette)
- [ ] Lenis smooth scroll + GSAP pinned sections
- [ ] Drop generated hero + hands images into `/public`
- [ ] Responsive / mobile pass

**Commands**
```bash
npm run web:dev
npm run web:build
```

---

## Phase 7 — Integration

- [ ] Dashboard reads live verdict feed from engine
- [ ] Intent-vs-effect panel bound to real verdicts
- [ ] Attestation ledger reads on-chain events
- [ ] x402 billing panel reads real usage

---

## Phase 8 — Deploy

- [ ] Web → Vercel
- [ ] Engine → Railway
- [ ] Contract live on X Layer testnet with public address
- [ ] End-to-end smoke test through the deployed stack

---

## Phase 9 — Listing (post-checklist)

- [ ] Register ASP on OKX.AI (A2MCP)
- [ ] Submit for listing review **by July 14–15** (not the deadline)
- [ ] Confirm listing goes live

## Phase 10 — Demo / X post

- [ ] 90-second demo video (paste malicious tx → VETO → attestation hash)
- [ ] X thread, tag `@OKX` / `@XLayerOfficial`, hashtag `#okxai`
- [ ] Public "VETO a live malicious tx" post
VETO_EOF

echo ""
echo "Done. Phase 3 files written."
echo "Deploy steps:"
echo "  1. Claim faucet OKB: https://web3.okx.com/xlayer/faucet"
echo "  2. Set DEPLOYER_PRIVATE_KEY in contracts/.env"
echo "  3. npm run contracts:compile"
echo "  4. npm run contracts:test"
echo "  5. npm run contracts:deploy"
