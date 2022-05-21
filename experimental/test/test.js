const chai = require("chai")
const assert = chai.assert

const precision = 1

describe("Lockable token tests", () => {

    let token
    let signer
    let address
    let unlockSchedule
    let toLock = 1000
    let totalLockTime

    before(async() => {

        signer = await hre.ethers.getSigner()
        address= await signer.getAddress()

        const timestamp = (await signer.provider.getBlock()).timestamp;
        unlockSchedule = {
            startDate: timestamp,
            endDate: timestamp + 1000
        }

        const Token = await hre.ethers.getContractFactory("LockableToken")
        token = await (await Token.deploy("Lockable Token", "LKT", unlockSchedule)).deployed()


        const MINTER_ROLE = await token.MINTER_ROLE()
        token.grantRole(MINTER_ROLE, address)
        token.mint(address, hre.ethers.constants.MaxUint256)
        const LOCK_ROLE = await token.LOCK_ROLE()
        token.grantRole(LOCK_ROLE, address)

        totalLockTime = unlockSchedule.endDate - unlockSchedule.startDate

    })

    it("should remove correct amount from balance when locking", async () => {

        const balanceBefore = await token.balanceOf(address)
        await (await token.lock(address, toLock)).wait()
        const balanceAfter = await token.balanceOf(address)
        assert.equal(balanceAfter, balanceBefore - toLock)

    })

    const skip = 0.5
    let toSkip
    let unlockableBefore
    let firstUnlockTimestamp

    it("should show the correct amount unlockable", async () => {
        toSkip = (totalLockTime) * skip
        firstUnlockTimestamp = unlockSchedule.startDate + toSkip
        await signer.provider.send("evm_mine", [firstUnlockTimestamp])

        unlockableBefore = await token.getUnlockable(address)
        assert.equal(unlockableBefore, toLock * skip)
    })

    it("unlocking should mint the correct amount and set the unlockable amount to 0", async () => {
        const balanceBefore = await token.balanceOf(address)
        await (await token.unlock()).wait()
        const unlockableAfter = await token.getUnlockable(address)
        const balanceAfter = await token.balanceOf(address)
        assert.equal(unlockableAfter, 0)
        assert.equal(balanceAfter, balanceBefore - unlockableBefore)
    })

    it("should unlock correctly after the first unlock", async() => {
        const leftToUnlock = toLock - unlockableBefore

        const timeLeft = totalLockTime - toSkip
        const secondUnlockTimestamp = firstUnlockTimestamp + timeLeft * skip 
        await signer.provider.send("evm_mine", [secondUnlockTimestamp])

        const secondUnlockableBefore = await token.getUnlockable(address)

        assert.closeTo(secondUnlockableBefore.toNumber(), leftToUnlock * skip, precision)

        await signer.provider.send("evm_mine", [unlockSchedule.endDate])

        const secondUnlockableAfter = await token.getUnlockable(address)

        assert.closeTo(secondUnlockableAfter.toNumber(), leftToUnlock, precision)
    })


})
