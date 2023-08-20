// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//  $$$$$$\   $$$$$$\  $$$$$$$$\ 
// $$  __$$\ $$  __$$\ $$  _____|
// $$ /  \__|$$ /  \__|$$ |      
// $$ |      \$$$$$$\  $$$$$\    
// $$ |       \____$$\ $$  __|   
// $$ |  $$\ $$\   $$ |$$ |      
// \$$$$$$  |\$$$$$$  |$$ |      
//  \______/  \______/ \__|  

/// @title CSF Referrals Contract
/// @author Sneakz
/// @notice This contract holds functions used in gameplay for Crypto Surferz at https://www.cryptosurferz.com/
/// @dev All function calls are tested and have been implemented on the Crypto Surferz Game complete with earn and burn mechanics

contract CSFReferrals is ReentrancyGuard, Ownable {

    /// @dev Contract variables
    uint256 public referralAmount = 500000*1e18;
    mapping(address => address) public referredUser;
    mapping(address => bool) public referredUserStatus;
    mapping(address => bool) public referBool;

    // @dev Events
    event ReferralAdded(address indexed Owner, address indexed ReferredUser);

    /// @dev Use this to assign a referral to a user
    /// @param _wallet The address to refer
    function referUser(address _wallet) public nonReentrant() returns (bool) {
        require(referredUserStatus[_wallet] == false, "User has already been referred!");
        referredUser[msg.sender] = _wallet;
        referBool[msg.sender] = true;
        referredUserStatus[_wallet] = true;
        emit ReferralAdded(msg.sender, _wallet);
        return true;
    }

    /// @dev User referral stats
    /// @param _wallet The address of the user
    /// @return array of user referral stats
    function referralStats(address _wallet) external view returns (bool, address, uint256) {
        return (
            referBool[_wallet],
            referredUser[_wallet],
            referralAmount
        );
    }

    /// @dev Used by owner to change referral cap
    /// @param _amount Cap amount to change to
    /// @return true if successful
    function changeReferralCap(uint256 _amount) external nonReentrant() onlyOwner() returns (bool) {
        referralAmount = _amount*1e18;
        return true;
    }
}