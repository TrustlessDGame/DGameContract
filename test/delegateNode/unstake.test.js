const { expect } = require("chai");
const { ethers } = require("hardhat");
const { Contract, Wallet } = require("zksync-ethers");
const { deployContract, deployOrUpgradeZk, getWallet } = require("../utils/deploy");
const { LOCAL_RICH_WALLETS } = require("../../hardhat.local.config");
const path = require("path");
const fs = require("fs");

describe("DelegateNode Contract - Stake and Unstake", function () {
  let delegateNode, token;
  let owner, admin, poolAdmin, moderator, user1, user2;
  let poolId = 1;
  const defaultUnstakeBufferTime = 60 * 60 * 24 * 7; // 7 days for example
  const getUserPoolInfo = async (userAddress, poolId) => {
      try {
          // Call the contract function to get UserPoolInfo for the given poolId and userAddress
          const userPoolInfo = await delegateNode._userPoolInfo(poolId, userAddress);

          // Extract the values from the returned struct (based on the return type in the ABI)
          const { stakedAmount, isStaked, claimedAmount, rewardAmount } = userPoolInfo;

          // Return the struct with formatted values
          return {
            stakedAmount: Number(ethers.utils.formatEther(stakedAmount.toString())),
            isStaked,
            claimedAmount: Number(ethers.utils.formatEther(claimedAmount.toString())),
            rewardAmount: Number(ethers.utils.formatEther(rewardAmount.toString())),
          };

      } catch (error) {
          console.error("Error accessing UserPoolInfo:", error);
          return null;
      }
  };

  before(async function() {
    owner = getWallet(LOCAL_RICH_WALLETS[0].privateKey);
    admin = getWallet(LOCAL_RICH_WALLETS[1].privateKey);
    poolAdmin = getWallet(LOCAL_RICH_WALLETS[2].privateKey);
    moderator = getWallet(LOCAL_RICH_WALLETS[3].privateKey);
    user1 = getWallet(LOCAL_RICH_WALLETS[4].privateKey);
    user2 = getWallet(LOCAL_RICH_WALLETS[5].privateKey);
  })
  beforeEach(async function () {
    // Clean up the .upgradable manifest
    const filePath = path.resolve(__dirname, "../../.upgradable/ZKsync-era-test-node.json");
    if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
    }
    // Deploy a mock ERC20 token to act as the wToken
    token = await deployContract(owner, "MyToken",[owner.address]);
    // const initialBalance = ethers.utils.parseEther("10000");
    await token.deployed();
    // await token.connect(owner).mint(owner.address, initialBalance);
    // await token.connect(owner).mint(admin.address, initialBalance);
    // await token.connect(owner).mint(poolAdmin.address, initialBalance);
    // await token.connect(owner).mint(moderator.address, initialBalance);
    // await token.connect(owner).mint(user1.address, initialBalance);
    // await token.connect(owner).mint(user2.address, initialBalance);
    console.log(token.address);
    // Deploy the DelegateNode contract

    const constructorArguments = [
      token.address,
      admin.address,
      poolAdmin.address,
      moderator.address];
    delegateNode = await deployOrUpgradeZk(owner, "DelegateNode", constructorArguments);
    console.log(delegateNode.address);
    // Admin creates a pool
    await delegateNode.connect(admin).adminCreatePool(1);

    // Set some default active amounts and unstake buffer time
    await delegateNode.connect(admin).adminUpdateAmountToActive(poolId, ethers.utils.parseEther("1000"));
    await delegateNode.connect(admin).setDefaultUnstakeBufferTime(defaultUnstakeBufferTime);
  });

  describe("Stake functionality", function () {
    it.only("should allow a user to stake tokens in an inactive pool", async function () {
      const stakeAmount = ethers.utils.parseEther("500");

      // Transfer tokens to the user and approve the contract to spend them
      await token.connect(owner).mint(user1.address, stakeAmount);
      await token.connect(user1).approve(delegateNode.address, stakeAmount);
      expect(await delegateNode.connect(user1).stake(poolId, stakeAmount)).to.emit(delegateNode, "Stake")
                   .withArgs(user1.address, stakeAmount, poolId);
      const poolInfo = await delegateNode._pools(poolId);
      expect(poolInfo.stakedAmount).to.equal(stakeAmount);
    });

    it("should revert if the stake amount is zero", async function () {
      //const tx = await delegateNode.connect(user1).stake(poolId, 0);
      await expect(delegateNode.connect(user1).stake(poolId, 0)).to.be.revertedWith("401");
    });

    it("should revert if the pool ID is invalid", async function () {
      await expect(delegateNode.connect(user1).stake(100, ethers.utils.parseEther("1"))).to.be.revertedWith("400");
    });

    it("should transition the pool to active when the stake reaches the activation threshold", async function () {
      const stakeAmount = ethers.utils.parseEther("1000");

      await token.connect(owner).mint(user1.address, stakeAmount);
      await token.connect(user1).approve(delegateNode.address, stakeAmount);
      const tx = await delegateNode.connect(user1).stake(poolId, stakeAmount);
      expect(tx)
        .to.emit(delegateNode, "ActivePool")
        .withArgs(poolId);

      const poolInfo = await delegateNode._pools(poolId);
      expect(poolInfo.status).to.equal(1);// Assuming 1 represents active status
    });

    it("should revert if stake amount exceeds the remaining stake needed for activation", async function () {
      await delegateNode.connect(admin).adminCreatePool(1);
      const stakeAmount = ethers.utils.parseEther("600");
      const poolId2 = 2;

      // Set a low activation threshold for testing
      await delegateNode.connect(admin).adminUpdateAmountToActive(poolId2, ethers.utils.parseEther("500"));

      await token.connect(owner).mint(user1.address, stakeAmount);
      await token.connect(user1).approve(delegateNode.address, stakeAmount);

      // Try staking more than the remaining amount needed for activation
      await expect(delegateNode.connect(user1).stake(poolId2, stakeAmount)).to.be.revertedWith("401");
    });

    it("should revert if trying to stake after pool becomes ACTIVE", async function () {
      const stakeAmount = ethers.utils.parseEther("1000");

      await token.connect(owner).mint(user1.address, stakeAmount);
      await token.connect(user1).approve(delegateNode.address, stakeAmount);

      // Stake enough to activate the pool
      await delegateNode.connect(user1).stake(poolId, stakeAmount);

      // Try staking again after the pool is active
      await expect(delegateNode.connect(user1).stake(poolId, ethers.utils.parseEther("100"))).to.be.revertedWith("404");
    });

    it("should revert when trying to stake while contract is paused", async function () {
      await delegateNode.connect(admin).pause();
      const stakeAmount = ethers.utils.parseEther("100");

      await token.connect(owner).mint(user1.address, stakeAmount);
      await token.connect(user1).approve(delegateNode.address, stakeAmount);
      await expect(delegateNode.connect(user1).stake(poolId, stakeAmount)).to.be.revertedWith("Pausable: paused");
    });
  });

  describe("Unstake functionality", function () {
    let stakeAmount;
    beforeEach(async function () {
      // Stake tokens to prepare for unstaking
      stakeAmount = ethers.utils.parseEther("500");
      await token.connect(owner).mint(user1.address, stakeAmount);
      console.log(-1);
      await token.connect(user1).approve(delegateNode.address, stakeAmount);
      console.log(-2);
      const tx = await delegateNode.connect(user1).stake(poolId, stakeAmount);
      await tx.wait();
      console.log(-3);
    });

    it.only("should allow a user to unstake tokens", async function () {
      console.log(delegateNode.address);
      const tx = await delegateNode.connect(user1).unstake(poolId);
      const receipt = await tx.wait();
      console.log(receipt);
      receipt.events.forEach((event) => {
        console.log(`Event Name: ${event.event}`);
        console.log(`Event Args: ${event.args}`);
      });
      await expect(delegateNode.connect(user1).unstake(poolId,{ gasLimit: 10000000 }))
        .to.emit(delegateNode, "UserUnstake")
        .withArgs(user1.address, poolId, {
          unstakeAmount: ethers.utils.parseEther("600"),
        });
      console.log(2);
      const poolInfo = await delegateNode._pools(poolId);
      console.log(3);
      expect(poolInfo.stakedAmount).to.equal(stakeAmount);
      console.log(4);

      const userInfo = await getUserPoolInfo(user1.address, poolId);
      console.log(userInfo);
      expect(userInfo.isStaked).to.equal(false);
      expect(userInfo.stakedAmount).to.equal(0);
      console.log(6);
    });

    it("should revert if the user tries to unstake with zero staked amount", async function () {
      // user2 hasn't staked any tokens, so unstaking should fail
      await expect(delegateNode.connect(user2).unstake(poolId)).to.be.revertedWith("ZeroStakedAmountError");
    });

    it("should not allow unstaking if the pool is in an invalid status", async function () {
      // Simulate changing pool status to something other than INACTIVE or ADMIN_WITHDREW
      await delegateNode.connect(admin).adminChangePoolStatus(poolId, 2); // Assuming 2 is an invalid state
      await expect(delegateNode.connect(user1).unstake(poolId)).to.be.revertedWith("InvalidPoolStatus");
    });

    it("should allow claiming unstaked tokens after buffer time", async function () {
      // Initiate an unstake process
      await delegateNode.connect(user1).unstake(poolId);

      // Move time forward to simulate buffer period elapsing (7 days in this case)
      await ethers.provider.send("evm_increaseTime", [defaultUnstakeBufferTime]);
      await ethers.provider.send("evm_mine");

      // Claim the unstaked tokens
      const tx = await delegateNode.connect(user1).userClaimUnstakedAmount(poolId);
      expect(tx)
        .to.emit(delegateNode, "UserClaimUnstakedAmount")
        .withArgs(user1.address, poolId, ethers.utils.parseEther("500"));

      const userInfo = await getUserPoolInfo(user1.address, poolId);
      expect(userInfo.stakedAmount).to.equal(0);
    });

    it("should revert if claiming unstake before buffer time has passed", async function () {
      // Initiate an unstake process
      await delegateNode.connect(user1).unstake(poolId);

      // Try to claim unstake without waiting for the buffer period
      await expect(delegateNode.connect(user1).userClaimUnstakedAmount(poolId)).to.be.revertedWith("PrematureClaimUnstake");
    });

    it("should revert when trying to unstake while contract is paused", async function () {
      await delegateNode.connect(admin).pause();
      await expect(delegateNode.connect(user1).unstake(poolId)).to.be.revertedWith("Pausable: paused");
    });
  });
});