const { ethers } = require("hardhat");

async function main() {
  const StableMintReserve = await ethers.getContractFactory("StableMintReserve");
  const stableMintReserve = await StableMintReserve.deploy();

  await stableMintReserve.deployed();

  console.log("StableMintReserve contract deployed to:", stableMintReserve.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
