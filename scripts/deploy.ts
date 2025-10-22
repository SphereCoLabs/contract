import { network } from "hardhat";


async function main() {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const sphereco = await viem.deployContract("SphereCo");

  const account = await viem.getWalletClient();

  // Get contract ABI and bytecode
  const artifact = await viem.getArtifact("SphereCo");
  const bytecode = artifact.bytecode;
  const abi = artifact.abi;

  // Get deployed contract address
  const contractAddress = await viem.deployContract({
    abi,
    bytecode,
    args: ["initial value"], // Pass constructor arguments here
});

console.log(`Contract deployed to: ${getAddress(contractAddress)}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});