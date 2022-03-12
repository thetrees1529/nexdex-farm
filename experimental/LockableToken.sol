//SPDX-License-Identifier: Unlicensed

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ILockableToken.sol";

pragma solidity 0.8.12;

struct LockInfo {
    uint locked;
    uint owed;
    uint debt;
}

contract LockableToken is ILockableToken, ERC20, AccessControl {

    constructor(string memory name, string memory symbol, uint unlockingStartDate_, uint unlockingEndDate_) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        require(unlockingStartDate_ >= block.timestamp);
        require(unlockingEndDate > unlockingStartDate_);
        unlockingStartDate = unlockingStartDate_;
        unlockingEndDate = unlockingEndDate_;
    }

    bytes32 public MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public LOCK_ROLE = keccak256("LOCK_ROLE");
    bytes32 public EARLY_UNLOCK_ROLE = keccak256("EARLY_UNLOCK_ROLE");

    uint public unlockingStartDate;
    uint public unlockingEndDate;

    mapping(address => LockInfo) _lockInfos;

    function lockOf(address account) external view returns(uint) {

        return _lockInfos[account].locked;

    }

    function unlockableOf(address account) public view returns(uint unlockable) {

        LockInfo storage lockInfo = _lockInfos[account];

        if(block.timestamp < unlockingStartDate) {
            return 0;
        }

        uint timeSince = unlockingStartDate - block.timestamp;
        uint totalLockTime = unlockingEndDate - unlockingStartDate;
        uint timeUnlocking = timeSince <= totalLockTime ? timeSince : totalLockTime;

        unlockable = (((timeUnlocking * lockInfo.locked) / totalLockTime) + lockInfo.owed) - lockInfo.debt;

    }

    function lock(address account, uint amount) external onlyRole(LOCK_ROLE) {

        if(block.timestamp >= unlockingEndDate) {
            return;
        }

        _transfer(account, address(this), amount);
        uint unlockableBefore = unlockableOf(account);

        LockInfo storage lockInfo = _lockInfos[account];
        lockInfo.locked += amount;

        uint unlockableAfter = unlockableOf(account);

        uint debt = unlockableAfter - unlockableBefore;

        lockInfo.debt += debt;

    }

    function unlock(uint amount) external {

        uint unlockableBefore = unlockableOf(msg.sender);

        require(amount <= unlockableBefore, "Cannot unlock this amount.");

        uint targetUnlockable = unlockableBefore - amount;

        LockInfo storage lockInfo = _lockInfos[msg.sender];
        lockInfo.locked -= amount;

        uint unlockableAfter = unlockableOf(msg.sender);

        uint owed = targetUnlockable - unlockableAfter;

        lockInfo.owed += owed;

        _transfer(address(this), msg.sender, amount);

    }

    function earlyUnlock(address account, uint amount) external onlyRole(EARLY_UNLOCK_ROLE) {

        _transfer(address(this), account, amount);
        uint unlockableBefore = unlockableOf(account);

        LockInfo storage lockInfo = _lockInfos[account];
        lockInfo.locked -= amount;

        uint unlockableAfter = unlockableOf(account);

        uint owed = unlockableAfter - unlockableBefore;

        lockInfo.owed += owed;
        
    }

    function mint(address account, uint amount) external onlyRole(MINTER_ROLE) {
        _mint(account, amount);
    }
    
}

