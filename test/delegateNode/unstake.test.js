const { expect } = require("chai");
const { ethers } = require("hardhat");
const { Contract, Wallet } = require("zksync-ethers");
const {
  deployContract,
  deployOrUpgradeZk,
  getWallet,
} = require("../utils/deploy");
const { LOCAL_RICH_WALLETS } = require("../../hardhat.local.config");
const path = require("path");
const fs = require("fs");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

const PoolStatus = Object.freeze({
  INACTIVE: 0,
  ACTIVE: 1,
  ADMIN_WITHDREW: 2,
  ADMIN_RETURNED_FUND: 3, // DONT USE this
  UNSTAKE_BUFFERING: 4, // UNSTAKE_BUFFERING can back to ADMIN_WITHDREW or WAIT_ADMIN_RETURNED_FUND
  WAIT_ADMIN_RETURNED_FUND: 5, // 21 days, after this 21 days, admin return fund to pool, and pool back to inactive, user claim unstake amount if exist in list unstake
});

describe("DelegateNode Contract - Stake and Unstake", function () {
  let delegateNode, token, workerHub;
  let owner, admin, poolAdmin, moderator, user1, user2;
  let poolId = 1;
  const defaultUnstakeBufferTime = 60 * 60 * 24 * 7; // 7 days for example
  const minimalStakeAmountToActive = ethers.parseEther("1000");
  const getUserPoolInfo = async (userAddress, poolId) => {
    try {
      // Call the contract function to get UserPoolInfo for the given poolId and userAddress
      const userPoolInfo = await delegateNode._userPoolInfo(
        poolId,
        userAddress
      );

      // Extract the values from the returned struct (based on the return type in the ABI)
      const { stakedAmount, isStaked, claimedAmount, rewardAmount } =
        userPoolInfo;

      // Return the struct with formatted values
      return {
        stakedAmount: Number(ethers.formatEther(stakedAmount.toString())),
        isStaked,
        claimedAmount: Number(ethers.formatEther(claimedAmount.toString())),
        rewardAmount: Number(ethers.formatEther(rewardAmount.toString())),
      };
    } catch (error) {
      console.error("Error accessing UserPoolInfo:", error);
      return null;
    }
  };

  before(async function () {
    owner = getWallet(LOCAL_RICH_WALLETS[0].privateKey);
    admin = getWallet(LOCAL_RICH_WALLETS[1].privateKey);
    poolAdmin = getWallet(LOCAL_RICH_WALLETS[2].privateKey);
    moderator = getWallet(LOCAL_RICH_WALLETS[3].privateKey);
    user1 = getWallet(LOCAL_RICH_WALLETS[4].privateKey);
    user2 = getWallet(LOCAL_RICH_WALLETS[5].privateKey);
  });
  beforeEach(async function () {
    // Clean up the .upgradable manifest
    const filePath = path.resolve(
      __dirname,
      "../../.upgradable/ZKsync-era-test-node.json"
    );
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
    // Deploy a mock ERC20 token to act as the wToken
    token = await deployContract(owner, "MyToken", [owner.address]);
    // const initialBalance = ethers.parseEther("10000");
    await token.waitForDeployment();
    workerHub = await deployContract(owner, "MockWorkerHub", [0]);
    await workerHub.waitForDeployment();
    // Deploy the DelegateNode contract

    const constructorArguments = [
      await token.getAddress(),
      admin.address,
      poolAdmin.address,
      moderator.address,
    ];
    delegateNode = await deployOrUpgradeZk(
      owner,
      "DelegateNode",
      constructorArguments
    );
    // console.log(await delegateNode.getAddress());
    // Admin creates a pool
    await delegateNode.connect(admin).adminCreatePool(1);

    // Set some default active amounts and unstake buffer time
    await delegateNode
      .connect(admin)
      .adminUpdateAmountToActive(poolId, minimalStakeAmountToActive);
    await delegateNode
      .connect(admin)
      .setDefaultUnstakeBufferTime(defaultUnstakeBufferTime);
    await delegateNode
      .connect(admin)
      .addminSetWorkerhubAddress(await workerHub.getAddress());
  });

  describe("Stake functionality", function () {
    it("should allow a user to stake tokens in an inactive pool", async function () {
      const stakeAmount = ethers.parseEther("500");

      // Transfer tokens to the user and approve the contract to spend them
      await token.connect(owner).mint(user1.address, stakeAmount);
      await token
        .connect(user1)
        .approve(await delegateNode.getAddress(), stakeAmount);
      await expect(delegateNode.connect(user1).stake(poolId, stakeAmount))
        .to.emit(delegateNode, "Stake")
        .withArgs(user1.address, stakeAmount, anyValue);
      const poolInfo = await delegateNode._pools(poolId);
      expect(poolInfo.stakedAmount).to.equal(stakeAmount);
    });

    it("should revert if the stake amount is zero", async function () {
      //const tx = await delegateNode.connect(user1).stake(poolId, 0);
      await expect(
        delegateNode.connect(user1).stake(poolId, 0)
      ).to.be.revertedWith("401");
    });

    it("should revert if the pool ID is invalid", async function () {
      await expect(
        delegateNode.connect(user1).stake(100, ethers.parseEther("1"))
      ).to.be.revertedWith("400");
    });

    it("should transition the pool to active when the stake reaches the activation threshold", async function () {
      const stakeAmount = minimalStakeAmountToActive;

      await token.connect(owner).mint(user1.address, stakeAmount);
      await token
        .connect(user1)
        .approve(await delegateNode.getAddress(), stakeAmount);
      await expect(
        delegateNode.connect(user1).stake(poolId, stakeAmount)
      ).to.emit(delegateNode, "ActivePool");

      const filter = delegateNode.filters.ActivePool;
      const events = await delegateNode.queryFilter(filter, -1);
      const [
        ,
        ,
        status,
        id,
        stakedAmount,
        amountToActive,
        ,
        ,
        ,
        stakedUsersSet,
      ] = events[0].args[0];

      expect(id).to.equal(poolId);
      expect(status).to.equal(1); // Assuming 1 represents active status
      expect(stakedAmount).to.equal(stakeAmount);
      expect(amountToActive).to.equal(minimalStakeAmountToActive); // Assuming 1 represents active status
      expect(stakedUsersSet).to.include.members([user1.address]);
    });

    it("should revert if stake amount exceeds the remaining stake needed for activation", async function () {
      await delegateNode.connect(admin).adminCreatePool(1);
      const stakeAmount = ethers.parseEther("600");
      const poolId2 = 2;

      // Set a low activation threshold for testing
      await delegateNode
        .connect(admin)
        .adminUpdateAmountToActive(poolId2, ethers.parseEther("500"));

      await token.connect(owner).mint(user1.address, stakeAmount);
      await token
        .connect(user1)
        .approve(await delegateNode.getAddress(), stakeAmount);

      // Try staking more than the remaining amount needed for activation
      await expect(
        delegateNode.connect(user1).stake(poolId2, stakeAmount)
      ).to.be.revertedWith("401");
    });

    it("should revert if trying to stake after pool becomes ACTIVE", async function () {
      const stakeAmount = ethers.parseEther("1000");

      await token.connect(owner).mint(user1.address, stakeAmount);
      await token
        .connect(user1)
        .approve(await delegateNode.getAddress(), stakeAmount);

      // Stake enough to activate the pool
      await delegateNode.connect(user1).stake(poolId, stakeAmount);

      // Try staking again after the pool is active
      await expect(
        delegateNode.connect(user1).stake(poolId, ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(delegateNode, "InvalidPoolStatus");
    });

    it("should revert when trying to stake while contract is paused", async function () {
      await delegateNode.connect(admin).pause();
      const stakeAmount = ethers.parseEther("100");

      await token.connect(owner).mint(user1.address, stakeAmount);
      await token
        .connect(user1)
        .approve(await delegateNode.getAddress(), stakeAmount);
      await expect(
        delegateNode.connect(user1).stake(poolId, stakeAmount)
      ).to.be.revertedWith("Pausable: paused");
    });
  });
  describe("Admin Deactivates the Pool", function () {
    beforeEach(async function () {
      await token
        .connect(owner)
        .mint(user1.address, minimalStakeAmountToActive);
      await token
        .connect(user1)
        .approve(await delegateNode.getAddress(), minimalStakeAmountToActive);
      await delegateNode
        .connect(user1)
        .stake(poolId, minimalStakeAmountToActive);
    });
    it("Should allow admin to withdraw from pool and change status to ADMIN_WITHDREW", async function () {
      // Admin withdraws from the pool, deactivating it
      await delegateNode
        .connect(poolAdmin)
        .adminWithdrawByPoolId(poolId, admin.address);

      // Verify pool status is now ADMIN_WITHDREW
      const poolInfo = await delegateNode._pools(poolId);
      expect(poolInfo.status).to.equal(2); // Assuming 2 is ADMIN_WITHDREW
    });

    it("Should allow user to unstake when pool is in ADMIN_WITHDREW state", async function () {
      // Admin withdraws from the pool, deactivating it
      await delegateNode
        .connect(poolAdmin)
        .adminWithdrawByPoolId(poolId, admin.address);
      await expect(delegateNode.connect(user1).unstake(poolId))
        .to.emit(delegateNode, "UserUnstake")
        .withArgs(user1.address, poolId, [
          minimalStakeAmountToActive,
          anyValue,
          PoolStatus.UNSTAKE_BUFFERING,
          anyValue,
          anyValue,
        ]);

      // Ensure user1's staked status is false after unstaking
      const userInfo = await getUserPoolInfo(user1.address, poolId);
      expect(userInfo.isStaked).to.equal(false);
    });
  });

  describe("Unstaking with Buffer Period", function () {
    beforeEach(async function () {
      await token
        .connect(owner)
        .mint(user1.address, minimalStakeAmountToActive);
      await token
        .connect(user1)
        .approve(await delegateNode.getAddress(), minimalStakeAmountToActive);
      await delegateNode
        .connect(user1)
        .stake(poolId, minimalStakeAmountToActive);
    });
    it("Should transition to UNSTAKE_BUFFERING state after first unstake request", async function () {
      // Admin deactivates pool
      await delegateNode
        .connect(poolAdmin)
        .adminWithdrawByPoolId(poolId, admin.address);

      // User1 initiates unstake
      await delegateNode.connect(user1).unstake(poolId);

      // Check that the pool has entered the UNSTAKE_BUFFERING state
      const poolInfo = await delegateNode._pools(poolId);
      expect(poolInfo.status).to.equal(PoolStatus.UNSTAKE_BUFFERING); // Assuming 3 represents UNSTAKE_BUFFERING

      // Check that the buffer period is set
      const poolUnstakedInfo = await delegateNode.poolUnstakedInfo(poolId);
      expect(poolUnstakedInfo.bufferTimeExpireAt).to.be.above(0);
    });

    it("Should prevent user from claiming tokens before buffer period expires", async function () {
      // Admin deactivates pool
      await delegateNode
        .connect(poolAdmin)
        .adminWithdrawByPoolId(poolId, admin.address);

      // User1 initiates unstake
      await delegateNode.connect(user1).unstake(poolId);

      // Check that buffer period is active and user cannot claim yet
      await expect(
        delegateNode.connect(user1).userClaimUnstakedAmount(poolId)
      ).to.be.revertedWithCustomError(delegateNode, "PrematureClaimUnstake");
    });

    xit("Should allow user claim unstaked amount after buffer[Missing flow]", async function () {
      await delegateNode
        .connect(admin)
        .updateMinerAddress(poolId, admin.address);
      expect(await token.balanceOf(user1.address)).to.equal(
        ethers.parseEther("0")
      );
      expect(await token.balanceOf(await delegateNode.getAddress())).to.equal(
        minimalStakeAmountToActive
      );
      await delegateNode
        .connect(poolAdmin)
        .adminWithdrawByPoolId(poolId, admin.address);
      await delegateNode.connect(user1).unstake(poolId);
      await ethers.provider.send("evm_increaseTime", [24 * 60 * 60]); // skip 1 days
      await ethers.provider.send("evm_mine", []); // mine a block
      await delegateNode
        .connect(admin)
        .minerReceiveReward(poolId, minimalStakeAmountToActive);
      await expect(delegateNode.connect(user1).userClaimUnstakedAmount(poolId))
        .to.emit(delegateNode, "UserClaimUnstakedAmount")
        .withArgs(user1.address, poolId, minimalStakeAmountToActive);

      expect(await token.balanceOf(await delegateNode.getAddress())).to.equal(
        ethers.parseEther("0")
      );
      expect(await token.balanceOf(user1.address)).to.equal(
        minimalStakeAmountToActive
      );
    });
  });

  describe("Edge Cases", function () {
    beforeEach(async function () {
      await token
        .connect(owner)
        .mint(user1.address, minimalStakeAmountToActive);
      await token
        .connect(user1)
        .approve(await delegateNode.getAddress(), minimalStakeAmountToActive);
      await delegateNode
        .connect(user1)
        .stake(poolId, minimalStakeAmountToActive);
    });
    it("Should prevent user from unstaking in ACTIVE state", async function () {
      // Pool is still ACTIVE, user cannot unstake
      await expect(
        delegateNode.connect(user1).unstake(poolId)
      ).to.be.revertedWithCustomError(delegateNode, "InvalidPoolStatus");
    });
  });
});
