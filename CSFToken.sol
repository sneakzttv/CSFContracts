// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//  $$$$$$\   $$$$$$\  $$$$$$$$\ 
// $$  __$$\ $$  __$$\ $$  _____|
// $$ /  \__|$$ /  \__|$$ |      
// $$ |      \$$$$$$\  $$$$$\    
// $$ |       \____$$\ $$  __|   
// $$ |  $$\ $$\   $$ |$$ |      
// \$$$$$$  |\$$$$$$  |$$ |      
//  \______/  \______/ \__|  

/// @title CSF Token Contract
/// @author Sneakz
/// @notice This contract holds functions used for the Crypto Surferz Token used in the game at https://www.cryptosurferz.com/
/// @dev All function calls are tested and have been implemented on the Crypto Surferz Game complete with earn and burn mechanics

contract CSFToken is ERC20, Ownable, ReentrancyGuard {
    constructor() ERC20("CSFToken", "CSF") {
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }

    /// @dev Custom Token Variables
    uint256 public tokensBurned;
    uint256 public tokensClaimed;
    uint256 public earnRatio = 1;

    /// @dev Custom Token Mappings
    mapping(address => bool) admin;
    mapping(address => int256) public earnSupply;
    mapping(address => bool) public gameTransferAuthority;

    /// @dev Assign this to a contract to enable minting
    /// @param _wallet The address to give admin to
    function addAdmin(address _wallet) public nonReentrant() onlyOwner() {
        admin[_wallet] = true;
        emit AdminAdded(_wallet);
    }

    /// @dev Assign this to a contract to disable minting
    /// @param _wallet The address to remove admin from
    function removeAdmin(address _wallet) public nonReentrant() onlyOwner() {
        admin[_wallet] = false;
        emit AdminRemoved(_wallet);
    }

    /// @dev Token events
    event AdminAdded(address indexed wallet);
    event AdminRemoved(address indexed wallet); 
    event IncreaseAllowance(address indexed _wallet, address indexed _spender, uint256 _value);
    event DecreaseAllowance(address indexed _wallet, address indexed _spender, uint256 _value);
    event GameTokenTransfer(address indexed _wallet, address indexed _to, uint256 _value);
    event Claim(address indexed _wallet, uint256 _value);
    event ScholarClaim(address indexed _wallet, uint256 _value);
    event LotteryStakeMint(address indexed _wallet, uint256 _value);
    event LotteryStakeBurn(address indexed _wallet, uint256 _value);
    event AdminBurn(address indexed _wallet, uint256 _value);
    event GameTransferAuthorityApprove(address indexed _wallet);

    /// @dev Custom CRC20 game functions
    /// @dev Used to control how many tokens users can mint at any given time (increased via staking / decreased via claims)
    /// @param _value The amount to increase the earn supply by 
    /// @return true if earn supply increase is successful
    function increaseEarnSupply(address _wallet, int256 _value) external nonReentrant() returns (bool) {
        require(admin[msg.sender] == true, "Only admins can do this");
        earnSupply[_wallet] += _value;
        return true;
    }

    /// @dev Used to control how many tokens users can mint at any given time (increased via staking / decreased via claims)
    /// @param _value The amount to decrease the earn supply by 
    /// @return true if earn supply decrease is successful
    function decreaseEarnSupply(address _wallet, int256 _value) external nonReentrant() returns (bool) {
        require(admin[msg.sender] == true, "Only admins can do this");
        if ((earnSupply[_wallet] - _value) >= 0) {
            earnSupply[_wallet] -= _value;
            return true;
        } else {
            return false;
        }
    }

    /// @dev Used to transfer from game functions as opposed to approve and transferFrom to save gas with an increase to user's balance and total supply
    /// @param _wallet The address sending tokens
    /// @param _wallet The address to send tokens to
    /// @param _value The amount to send to the users address
    /// @return true if transfer for mint is successful
    function gameTokenTransfer(address _wallet, address _to, uint256 _value) external nonReentrant() returns (bool) {
        require(admin[msg.sender] == true, "Only admins can do this");
        require(gameTransferAuthority[_wallet] == true, "This wallet doesn't have game transfer authority enabled");
        _burn(_wallet, _value);
        _mint(_to, _value);
        emit GameTokenTransfer(_wallet, _to, _value);
        return true;
    }

    /// @dev Used for game earn claims with a check against earn supply and an increase to total supply
    /// @param _wallet The address to send tokens to
    /// @param _value The amount to send to the users address
    /// @return true if transfer of tokens for claim is successful
    function claim(address _wallet, uint256 _value) external nonReentrant() returns (bool) {
        require(admin[msg.sender] == true, "Only admins can do this");
        require(((earnSupply[_wallet]*int256(earnRatio))/365) >= int256(_value), "Not Enough Earn Supply");
        require(gameTransferAuthority[_wallet] == true, "This wallet doesn't have game transfer authority enabled");
        _mint(_wallet, _value);
        tokensClaimed += _value;
        emit Claim(_wallet, _value);
        return true;
    }

    /// @dev Used for scholar claims
    /// @param _wallet The address to send tokens to
    /// @param _value The amount to send to the users address
    /// @return true if transfer is successful
    function scholarClaim(address _wallet, uint256 _value) external nonReentrant() returns (bool) {
        require(admin[msg.sender] == true, "Only admins can do this");
        require(gameTransferAuthority[_wallet] == true, "This wallet doesn't have game transfer authority enabled");
        _mint(_wallet, _value);
        tokensClaimed += _value;
        emit ScholarClaim(_wallet, _value);
        return true;
    }

    /// @dev Used for lottery & staking
    /// @param _wallet The address to send tokens to
    /// @param _value The amount to send to the users address
    /// @return true if transfer is successful
    function lotteryStakeMint(address _wallet, uint256 _value) external nonReentrant() returns (bool) {
        require(admin[msg.sender] == true, "Only admins can do this");
        _mint(_wallet, _value);
        emit LotteryStakeMint(_wallet, _value);
        return true;
    }

    /// @dev Used for lottery & staking
    /// @param _wallet The address to burn tokens from
    /// @param _value The amount to burn from the users address
    /// @return true if transfer is successful
    function lotteryStakeBurn(address _wallet, uint256 _value) external nonReentrant() returns (bool) {
        require(admin[msg.sender] == true, "Only admins can do this");
        require(gameTransferAuthority[_wallet] == true, "This wallet doesn't have game transfer authority enabled");
        _burn(_wallet, _value);
        emit LotteryStakeBurn(_wallet, _value);
        return true;
    }

    /// @dev Used for token burns
    /// @param _wallet The address to burn tokens from
    /// @param _value The amount to burn from the users address
    /// @return true if token burn is successful
    function burn(address _wallet, uint256 _value) external nonReentrant() returns (bool) {
        require(admin[msg.sender] == true, "Only admins can do this");
        require(gameTransferAuthority[_wallet] == true, "This wallet doesn't have game transfer authority enabled");
        _burn(_wallet, _value);
        tokensBurned += _value;
        emit AdminBurn(_wallet, _value);
        return true;
    }

    /// @dev Used to enable game token transfers for security
    /// @param _wallet The address approving the authority
    /// @return true if token burn is successful
    function gameTransferAuthorityApprove(address _wallet) external nonReentrant() returns (bool) {
        require(admin[msg.sender] == true, "Only admins can do this");
        gameTransferAuthority[_wallet] = true;
        emit GameTransferAuthorityApprove(_wallet);
        return true;
    }

    /// @dev Owner may use this to change earn ratio
    /// @param _ratio The ratio to change to
    /// @return true if earn ratio change successful
    function changeEarnRatio(uint _ratio) public nonReentrant() onlyOwner() returns (bool) {
        earnRatio = _ratio;
        return true;
    }

    /// @dev Total burn ratio
    /// @return burn ratio of tokens burned vs tokens claimed
    function globalTokenStats() external view returns (uint256, uint256) {
        return (tokensClaimed, tokensBurned);
    }
}