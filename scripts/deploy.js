const hre = require("hardhat");

async function main() {
  console.log("Starting deployment of Certificate Insurance and Verification System...");
  
  // Get the ContractFactory and Signers
  const [deployer] = await hre.ethers.getSigners();
  
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  
  // Deploy the Project contract
  const Project = await hre.ethers.getContractFactory("Project");
  console.log("Deploying Project contract...");
  
  const project = await Project.deploy();
  await project.deployed();
  
  console.log("Project contract deployed to:", project.address);
  console.log("Transaction hash:", project.deployTransaction.hash);
  
  // Wait for a few confirmations
  console.log("Waiting for confirmations...");
  await project.deployTransaction.wait(2);
  
  console.log("Deployment completed successfully!");
  console.log("\n=== Contract Details ===");
  console.log("Contract Address:", project.address);
  console.log("Network:", hre.network.name);
  console.log("Deployer:", deployer.address);
  
  // Save deployment info
  const deploymentInfo = {
    contractAddress: project.address,
    network: hre.network.name,
    deployer: deployer.address,
    deploymentDate: new Date().toISOString(),
    transactionHash: project.deployTransaction.hash
  };
  
  console.log("\n=== Deployment Info ===");
  console.log(JSON.stringify(deploymentInfo, null, 2));
  
  // Verify contract on Core Testnet 2 (if verification is supported)
  if (hre.network.name === "core_testnet2") {
    console.log("\n=== Contract Verification ===");
    console.log("Note: Manual verification may be required on Core Testnet 2");
    console.log("Contract source code is available in the contracts/ directory");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
