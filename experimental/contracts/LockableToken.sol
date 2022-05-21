//SPDX-License-Identifier: Unlicensed

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

pragma solidity 0.8.14;

struct LockInfo {
    uint locked;
    uint lastUnlocked;
}

interface ILockableToken {

    struct UnlockSchedule {
        uint startDate;
        uint endDate;
    }

    function MINTER_ROLE() external view returns(bytes32);
    function LOCK_ROLE() external view returns(bytes32);
    function EARLY_UNLOCK_ROLE() external view returns(bytes32);

    function getUnlockSchedule() external view returns(UnlockSchedule memory);

    function getLocked(address account) external view returns(uint);

    function getUnlockable(address account) external view returns(uint);

    function unlock() external;

    function lock(address account, uint amount) external;

    function earlyUnlock(address account, uint amount) external;
    
}
contract LockableToken is ILockableToken, ERC20, AccessControl {

    constructor(string memory name, string memory symbol, UnlockSchedule memory unlockSchedule) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _unlockSchedule = unlockSchedule;
    }

    bytes32 public MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public LOCK_ROLE = keccak256("LOCK_ROLE");
    bytes32 public EARLY_UNLOCK_ROLE = keccak256("EARLY_UNLOCK_ROLE");

    UnlockSchedule private _unlockSchedule;
    mapping(address => LockInfo) private _lockInfos;

    function mint(address account, uint amount) external onlyRole(MINTER_ROLE) {
        _mint(account, amount);
    }

    function getUnlockSchedule() external view returns(UnlockSchedule memory) {
        return _unlockSchedule;
    }

    function getLocked(address account) external view returns(uint) {
        return _lockInfos[account].locked;
    }

    function getUnlockable(address account) public view returns(uint) {
        if(block.timestamp < _unlockSchedule.startDate) {
            return 0;
        }
        LockInfo storage lockInfo = _lockInfos[account];
        if(block.timestamp >= _unlockSchedule.endDate) {
            return lockInfo.locked;
        }
        uint unlockingSince = lockInfo.lastUnlocked > _unlockSchedule.startDate ? lockInfo.lastUnlocked : _unlockSchedule.startDate;
        uint unlockingFor = block.timestamp - unlockingSince;
        uint totalUnlockTime = _unlockSchedule.endDate - unlockingSince;
        return (lockInfo.locked * unlockingFor) / totalUnlockTime;
    }

    function unlock() external {
        _unlock(msg.sender);
    }

    function earlyUnlock(address account, uint amount) external onlyRole(EARLY_UNLOCK_ROLE) {
        _unlock(account);
        _lockInfos[account].locked -= amount;
        _mint(account, amount);
    }

    function _unlock(address account) private {
        uint toUnlock = getUnlockable(account);
        LockInfo storage lockInfo = _lockInfos[account];
        lockInfo.locked -= toUnlock;
        lockInfo.lastUnlocked = block.timestamp;
        _mint(account, toUnlock);
    }

    function lock(address account, uint amount) external onlyRole(LOCK_ROLE) {
        _lockInfos[account].locked += amount;
        _burn(account, amount);
    }
    
}

