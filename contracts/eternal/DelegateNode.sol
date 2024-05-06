pragma solidity ^0.8.0;

// DelegateNode contract is similar to staking contract, allow users stake $EAI, if enough $EAI staked, backend will manually start a miner
// Miner run something outside login and earn reward, then reward will be split to users
// mean a user dont have enough $EAI to run a miner, they stake with other people to run a miner
// Contract is upgradeable and keep track about stake info (address, amount, block_time, etc)
// Will create pool to receive $EAI stake from user
// We have some pools (similar to ERC-721), each pools have different state: id, status, staked amount

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

import "../libs/helpers/Errors.sol";
import "../libs/structs/DelegateNode.sol";

contract DelegateNode is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using AddressUpgradeable for address;

    // event
    event CreatePool(uint32 poolId);
    event Stake(address user, uint256 amount, uint32 poolId);
    event ActivePool(uint32 poolId);
    event DeActivePool(uint32 poolId);
    event UnStake(address user, uint256 amount, uint32 poolId,uint256 claimedBlock);
    event ClaimUnStake(address user, uint256 amount, uint32 poolId,uint256 claimedBlock);
    event ReStakeUnStakedPool(address user,uint256 unStakedAmount,uint32 oldPoolId,uint32 newPoolId);

    address public _admin;
    uint32 public _nextPoolId;
    uint256 public _defaultAmountToActive; // 8000 EAI
    mapping(uint32 => DelegateNodeStruct.PoolInfo) public _pools;
    uint32 public _defaultPoolFee; // 1000 => 10%
    uint256 public _defaultWaitBlock; // (21 +7 )day * 24 hour * 60 min * 30 block (block time  = 2s)

    function initialize(
        address admin
    )  initializer public {
        _admin = admin;
        _defaultAmountToActive = 8000 * 10**18;
        _defaultPoolFee = 1000;
        _defaultWaitBlock= 28*24*60*30 ;
        __ERC721_init("DelegateNode", "DN");
        __ReentrancyGuard_init();
        __Ownable_init();
    }

    // modifier admin only
    modifier onlyAdmin() {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        _;
    }

    function changeAdmin(address newAdm) external {
        require(msg.sender == _admin && newAdm != Errors.ZERO_ADDR, Errors.ONLY_ADMIN_ALLOWED);

        // change admin
        if (_admin != newAdm) {
            _admin = newAdm;
        }
    }

//    function getPoolInfo(uint32 poolId) external view returns (DelegateNodeStruct.PoolInfo memory) {
//        return _pools[poolId];
//    }

    // ADMIN update amountToActive for a pool
    function adminUpdateAmountToActive(uint32 poolId, uint256 amount) external onlyAdmin {
        require(poolId > 0 && poolId <= _nextPoolId, Errors.INV_GAME_ID);
        require(amount > 0, Errors.INV_ADD);

        _pools[poolId].amountToActive = amount;
    }


    // admin set name for pool
    function adminSetName(uint32 poolId, string memory name) external onlyAdmin {
        require(poolId > 0 && poolId <= _nextPoolId, Errors.INV_GAME_ID);

        _pools[poolId].name = name;
    }

    // admin set image for pool
    function adminSetImage(uint32 poolId, string memory image) external onlyAdmin {
        require(poolId > 0 && poolId <= _nextPoolId, Errors.INV_GAME_ID);

        _pools[poolId].image = image;
    }


    // Admin change fee percent for a pool
    function adminChangeFeePercent(uint32 poolId, uint32 feePercent) external onlyAdmin {
        require(poolId > 0 && poolId <= _nextPoolId, Errors.INV_GAME_ID);
        require(feePercent > 0, Errors.INV_ADD);

        _pools[poolId].feePercent = feePercent;
    }

    function adminCreatePool(uint32 amountPool) external onlyAdmin {
        // loop to PRE-CREATE pool
        for (uint32 i = 0; i < amountPool; i++) {
            _nextPoolId = _nextPoolId + 1;
            DelegateNodeStruct.PoolInfo storage pool = _pools[_nextPoolId];
            pool.status = DelegateNodeStruct.PoolStatus.INACTIVE;
            pool.id = _nextPoolId;
            pool.amountToActive = _defaultAmountToActive;
            pool.stakedAmount = 0;
            pool.feePercent = _defaultPoolFee;

            emit CreatePool(_nextPoolId);
        }
    }

    function internalUpdatePoolInfo(uint32 poolId, uint256 amount) private pure  {
        // update pool info
        _pools[poolId].stakedAmount = _pools[poolId].stakedAmount + amount;
        _pools[poolId].stakedInfos.push(DelegateNodeStruct.StakedInfo({
            user: msg.sender,
            amount: amount,
            blockNumber: block.number
        }));

        if (_pools[poolId].stakedAmount >= _pools[poolId].amountToActive) {
            _pools[poolId].status = DelegateNodeStruct.PoolStatus.ACTIVE;
            // Emit for Backend enough $EAI to start a miner
            emit ActivePool(poolId); // BE listen, BE create wallet for miner, BE start miner manually
        }

    }
    // stake function is payable, user dont input pool, contract will FIND FIRST pool INACTIVE to stake
    function stake(uint32 poolId, uint256 amount) external payable nonReentrant {
        require(amount > 0, Errors.INV_ADD);
        require(msg.value == amount, Errors.INV_ADD);
        require(poolId > 0, Errors.INV_ADD);
        internalUpdatePoolInfo(poolId,amount);
        emit Stake(msg.sender, amount, poolId);
    }

    // withdraw $EAI, for admin only, $EAI is native token of chain
    function adminWithdraw(address to, uint256 amount) external onlyAdmin {
        require(to != Errors.ZERO_ADDR, Errors.INV_ADD);
        require(amount > 0, Errors.INV_ADD);

        payable(to).transfer(amount);
    }

    // withdraw $EAI by poolId, for admin only, $EAI is native token of chain
    function adminWithdrawByPoolId(uint32 poolId, address to, uint256 amount) external onlyAdmin {
        require(to != Errors.ZERO_ADDR, Errors.INV_ADD);
        require(amount > 0, Errors.INV_ADD);

        _pools[poolId].stakedAmount = _pools[poolId].stakedAmount - amount;
        payable(to).transfer(amount);
    }

    function unStake(uint32 poolId) external {
        require(poolId > 0, Errors.INV_ADD);
        require(poolId <= _nextPoolId, Errors.INV_ADD);

        var unStakedAmount = 0;
        stakedInfos = _pools[poolId].stakedInfos;
        for (uint32 i = 0; i < stakedInfos.length; i++) {
            StakedInfo memory stakeInfo = stakedInfos[i];
            if (stakeInfo.user == msg.sender && stakeInfo.amount > 0) {
                unStakedAmount=unStakedAmount+stakeInfo.amount;
                stakeInfo.amount=0;
            }
        }
        require(unStakedAmount > 0, Errors.INV_ADD);
        require(_pools[poolId].stakedAmount > unStakedAmount, Errors.INV_ADD);
        _pools[poolId].stakedAmount = _pools[poolId].stakedAmount - unStakedAmount;
        if (_pools[poolId].stakedAmount < _pools[poolId].amountToActive) {
            _pools[poolId].status = DelegateNodeStruct.PoolStatus.INACTIVE;

            // Emit for Backend enough $EAI to start a miner
            emit DeActivePool(poolId); // BE listen, BE create wallet for miner, BE start miner manually
        }
        claimedBlock = block.number + _defaultWaitBlock;
        var oldAmount = _pools[poolId].mapUnStakedInfos[msg.sender].caps[claimedBlock];
        _pools[poolId].mapUnStakedInfos[msg.sender].caps[claimedBlock]=oldAmount+unStakedAmount;
        _pools[poolId].mapUnStakedInfos[msg.sender].blocks.push(claimedBlock);
        emit UnStake(msg.sender, unStakedAmount, poolId,claimedBlock);
    }

    function claimUnStake(uint32 poolId,uint256 claimedBlock) external payable {
        require(poolId > 0, Errors.INV_ADD);
        require(poolId <= _nextPoolId, Errors.INV_ADD);
        require(block.number > claimedBlock, Errors.INV_ADD);
        var amount = _pools[poolId].mapUnStakedInfos[msg.sender].caps[claimedBlock];
        require(amount > 0, Errors.INV_ADD);
        msg.sender.transfer(amount);
        emit ClaimUnStake(msg.sender, unStakedAmount, poolId,claimedBlock);
    }

    function reStakeUnStakedPool(uint32 oldPoolId,uint32 newPoolId) external {
        require(oldPoolId > 0, Errors.INV_ADD);
        require(oldPoolId > 0, Errors.INV_ADD);
        require(newPoolId <= _nextPoolId, Errors.INV_ADD);
        require(newPoolId <= _nextPoolId, Errors.INV_ADD);

        UnStakedInfo memory unStakeInfo = _pools[oldPoolId].mapUnStakedInfos[msg.sender];
        unStakedAmount = 0 ;
        for (uint32 i = 0; i < unStakeInfo.blocks.length; i++) {
            unStakedAmount = unStakedAmount + unStakeInfo.caps[unStakeInfo.blocks[i]];
            unStakeInfo.caps[unStakeInfo.blocks[i]]=0;
        }
        require(unStakedAmount > 0, Errors.INV_ADD);
        internalUpdatePoolInfo(newPoolId,unStakedAmount);
        emit ReStakeUnStakedPool(msg.sender,unStakedAmount,oldPoolId,newPoolId);
    }
}


