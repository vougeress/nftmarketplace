const hre = require("hardhat");

async function main() {

  const NftMarketplace = await hre.ethers.getContractFactory("NftMarketplace");
  const nftmarketplace = await NftMarketplace.deploy();


  console.log(
    `deployed contract address ${nftmarketplace.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});