const hre = require("hardhat");

async function main() {
  const net = hre.network.name;
  const [deployer] = await hre.ethers.getSigners();
  const bal = await hre.ethers.provider.getBalance(deployer.address);

  console.log("Network:  ", net);
  console.log("Deployer: ", deployer.address);
  console.log("Balance:  ", hre.ethers.formatEther(bal), "OKB");

  if (bal === 0n) {
    console.log("\nDeployer has 0 OKB on this network.");
    console.log("  Mainnet: withdraw OKB to X Layer from OKX Exchange, or bridge at");
    console.log("           https://www.okx.com/xlayer/bridge");
    console.log("  Testnet: https://web3.okx.com/xlayer/faucet\n");
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
  console.log("\n  Explorer: https://www.okx.com/web3/explorer/xlayer/address/" + address);
  console.log("\nNext steps:");
  console.log("  1. Put this in apps/engine/.env:");
  console.log(`       ATTESTATION_ADDRESS=${address}`);
  console.log("  2. Keep the deploy tx hash above as a proof artifact.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
