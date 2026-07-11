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
