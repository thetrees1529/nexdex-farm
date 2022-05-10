const NanoXp = artifacts.require("NanoXp.sol");
const XpBar = artifacts.require("XpBar.sol");
const MasterGamer = artifacts.require("MasterGamer.sol");

module.exports = async function (deployer, network, addresses) {
  // deploy nXP, xpBar, masterGamer,
  const nXp = await deployer.deploy(NanoXp)
  const xpBar = await deployer.deploy(XpBar, nXp.address)

  await deployer.deploy(MasterGamer, nXp.address, xpBar.address, addresses[0], 66000000000000000000, 22910900)
};
