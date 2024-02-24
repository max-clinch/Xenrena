const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const Xenrena = await ethers.getContractFactory("Xenrena");
  const xenrena = await upgrades.deployProxy(Xenrena, [], { initializer: 'initialize' });

  await xenrena.deployed();

  console.log("Xenrena deployed to:", xenrena.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
