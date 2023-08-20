// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "/contracts/CSFToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

//  $$$$$$\   $$$$$$\  $$$$$$$$\ 
// $$  __$$\ $$  __$$\ $$  _____|
// $$ /  \__|$$ /  \__|$$ |      
// $$ |      \$$$$$$\  $$$$$\    
// $$ |       \____$$\ $$  __|   
// $$ |  $$\ $$\   $$ |$$ |      
// \$$$$$$  |\$$$$$$  |$$ |      
//  \______/  \______/ \__|  

/// @title CSF User Stats Contract
/// @author Sneakz
/// @notice This contract holds functions used in gameplay for Crypto Surferz at https://www.cryptosurferz.com/
/// @dev All function calls are tested and have been implemented on the Crypto Surferz Game complete with earn and burn mechanics
/// @dev Make sure this contract has admin role rights from the token contract to enable minting on claims

contract CSFUserStats is ReentrancyGuard, Ownable {
    /// @dev Initializes the ERC20 token
    CSFToken immutable _token;

    /// @dev Constructor sets token to be used, input the CSF token address here on deployment
    constructor (CSFToken token) {
        _token = token;
    }

    /// @dev Contract variables
    uint256 public pveEarnCap = 1000000*1e18;
    uint256 public scholarshipEarnCap = 100000*1e18;
    uint256 public shopItemPrice = 500000*1e18;
    uint256 public stakingCap = 100000000*1e18;
    uint256 public pvpCap = 1000000*1e18;
    uint256 public memberCount = 0;
    uint256 globalId = 1;
    /// @dev Wallet that tokens go to on purchases
    address devWallet = 0x76131D0bA1e061167Df4ED539bA9CF87aC58a323;
    /// @dev wallet that auth signatures come from
    address authWallet = 0xbee02166dd883D911b614990957b1726f92779d9;

    /// @dev Contract mappings
    mapping(address => string) public userName;
    mapping(address => uint256) public idMapping;
    /// @dev Shop items and bonus mappings
    mapping(address => uint256) public surfCoinz;
    mapping(address => uint256) public speedBonus;
    mapping(address => uint256) public livesBonus;
    mapping(address => uint256) public pointsBonus;
    mapping(address => uint256) public speedBonusTr;
    mapping(address => uint256) public livesBonusTr;
    mapping(address => uint256) public pointsBonusTr;
    mapping(address => uint256) public weaponOil;
    mapping(address => uint256) public weaponThunder;
    mapping(address => uint256) public weaponBomb;
    mapping(address => uint256) public claimTimerBonuses;
    /// @dev Earn and staking mappings
    mapping(address => uint256) public stakeTotal;
    mapping(address => uint256) public timeStaked;
    mapping(address => uint256) public earnPendingPVE;
    mapping(address => uint256) public earnTotalPVE;
    mapping(address => uint256) public claimTimerPVE;
    /// @dev Scholarship mappings
    mapping(address => address) public scholarshipManager;
    mapping(address => address) public scholar;
    mapping(address => bool) public scholarBool;
    mapping(address => bool) public scholarshipBool;
    mapping (address => uint256) public changeScholarTimer;
    mapping(address => uint256) public claimTimerScholar;
    mapping(address => uint256) public earnPendingScholarship;
    mapping(address => uint256) public earnTotalScholarship;
    /// @dev Exclusive perk for users
    mapping(address => bool) public ogUserPerk;
    /// @dev Blacklist mappings
    mapping(address => bool) public blacklist;
    /// @dev PVP mappings
    mapping(address => uint256) public pvpWager;
    /// @dev Nonce to stop cheaters
    mapping(address => uint256) public nonce;
    /// @dev Moderator mapping
    mapping(address => bool) moderator;

    /// @dev Contract events
    event SaveScore(address indexed wallet, uint256 score);
    event AddStake(address indexed wallet, uint256 amount);
    event RemovedStake(address indexed wallet, uint256 amount);
    event ClaimedScholarship(address indexed wallet, uint256 amount);
    event ClaimedPVE(address indexed wallet, uint256 amount);
    event BuySurfcoinz(address indexed wallet, uint256 amount);
    event BuyShopItem(address indexed wallet, uint256 surfcoinz);
    event BuyWeapons(address indexed wallet, uint256 amount);
    event ChangeScholar(address indexed wallet, address indexed scholar);
    event ChangeScholarManager(address indexed wallet, address indexed manager);
    event ChangeOGUserPerk(address indexed wallet);
    event ModeratorAdded(address indexed wallet); 
    event ModeratorRemoved(address indexed wallet);
    event ModChangeStats(address indexed moderator, address indexed wallet, uint256 surfcoinz, uint256 earnPendingPVE, uint256 weapons);
    /// @dev Blacklist events
    event AddToBlacklist(address indexed wallet, string indexed userName);
    event ModAddBlacklist(address indexed modWallet, address indexed wallet, string indexed userName);
    event ModRemoveBlacklist(address indexed modWallet, address indexed wallet, string indexed userName);
    /// @dev PVP events
    event SetPVPWager(address indexed wallet, uint256 amount);
    event AcceptPVPWager(address indexed wallet, address indexed opponent, uint256 amount);
    event ClaimedPVPWinnings(address indexed wallet, address indexed opponent, uint256 amount);

    /// @dev Contract functions

    /// @dev Assign this to an address to enable moderator actions
    /// @param _wallet The address to give moderator to
    function addModerator(address _wallet) public nonReentrant() onlyOwner() returns (bool) {
        moderator[_wallet] = true;
        ogUserPerk[_wallet] = true;
        emit ModeratorAdded(_wallet);
        return true;
    }

    /// @dev Assign this to an address to disable moderator actions
    /// @param _wallet The address to remove moderator from
    function removeModerator(address _wallet) public nonReentrant() onlyOwner() returns (bool) {
        moderator[_wallet] = false;
        ogUserPerk[_wallet] = false;
        emit ModeratorRemoved(_wallet);
        return true;
    }

    /// @dev Allows moderators to alter game stats for support reasons
    /// @notice Changing a users stats
    /// @param _wallet The wallet of the user to be altered
    /// @param _surfcoinz The surfcoinz of the address to be altered
    /// @param _earnPendingPVE The earn pending PVE of the address to be altered
    /// @param _weapons The amount of weapons of the address to be altered
    /// @return true if successful
    function modChangeStats(address _wallet, uint256 _surfcoinz, uint256 _earnPendingPVE, uint256 _weapons) external nonReentrant() returns (bool) {
        require(moderator[msg.sender] == true, "Only moderators can do this");
        surfCoinz[_wallet] += _surfcoinz;
        earnPendingPVE[_wallet] += _earnPendingPVE;
        weaponOil[_wallet] = _weapons;
        weaponThunder[_wallet] = _weapons;
        weaponBomb[_wallet] = _weapons;
        emit ModChangeStats(msg.sender, _wallet, _surfcoinz, _earnPendingPVE, _weapons);
        return true;
    }

    /// @dev Blacklist functions

    /// @dev adds user to the blacklist and stops them from entering the game
    /// param _wallet The address being added to the blacklist
    /// param _userName The username that belongs to the wallet
    /// return true on success false on fail
    function addBlacklist(string memory _userName) external nonReentrant() returns (bool) {
        blacklist[msg.sender] = true;
        emit AddToBlacklist(msg.sender, _userName);
        return true;
    }

    /// @dev Adds a user to the blacklist, can only be called by owner
    /// param _wallet The address being added to the blacklist
    /// param _userName The username that belongs to the wallet
    /// return true on success false on fail
    function modAddBlacklist(address _wallet, string memory _userName) external nonReentrant() returns (bool) {
        require(moderator[msg.sender] == true, "Only moderators can do this");
        blacklist[_wallet] = true;
        emit ModAddBlacklist(msg.sender, _wallet, _userName);
        return true;
    }

    /// @dev Removes a user from the blacklist, can only be called by owner
    /// param _wallet The address being removed from the blacklist
    /// param _userName The username that belongs to the wallet
    /// return true on success false on fail
    function modRemoveBlacklist(address _wallet, string memory _userName) external nonReentrant() returns (bool) {
        require(moderator[msg.sender] == true, "Only moderators can do this");
        blacklist[_wallet] = false;
        emit ModRemoveBlacklist(msg.sender, _wallet, _userName);
        return true;
    }

    /// @dev User stats functions

    /// @dev Adds address to the system, used on game entry to create a new account
    /// @notice Creating a new account
    /// @param _userName The username of the address creating the account
    /// @return true if successful
    function addMember(string memory _userName) external nonReentrant() returns (bool) {
        require(idMapping[msg.sender] == 0, "Account already exists");
        _token.gameTransferAuthorityApprove(msg.sender);
        idMapping[msg.sender] = globalId;
        userName[msg.sender] = _userName;
        ++globalId;
        ++memberCount;
        return true;
    }

    /// @dev PVE earn functions

    /// @dev Used when saving score in game to the chain
    /// @notice Save your scores and earn
    /// @param _surfcoinz The surfcoinz of the address
    /// @param _speedBonus The speed bonus of the address
    /// @param _livesBonus The lives bonus of the address
    /// @param _pointsBonus The points bonus of the address
    /// @param _speedBonusTr The speed bonus time remaining of the address
    /// @param _livesBonusTr The lives bonus time remaining of the address
    /// @param _pointsBonusTr The points bonus time remaining of the address
    /// @param _weaponOil The weapon oil of the address
    /// @param _weaponThunder The weapon thunder of the address
    /// @param _weaponBomb The weapon bombs of the address
    /// @param _earnPendingPVE The earn pending PVE of the address
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function saveScore(
        uint256 _surfcoinz,
        uint256 _speedBonus,
        uint256 _livesBonus,
        uint256 _pointsBonus,
        uint256 _speedBonusTr,
        uint256 _livesBonusTr,
        uint256 _pointsBonusTr,
        uint256 _weaponOil,
        uint256 _weaponThunder,
        uint256 _weaponBomb,
        uint256 _earnPendingPVE,
        bytes memory _sig
    ) 
        external
        nonReentrant()
        returns (bool)
    {
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _earnPendingPVE + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        require(scholarshipBool[msg.sender] == false, "Scholarship active");
        surfCoinz[msg.sender] = _surfcoinz;
        speedBonus[msg.sender] = _speedBonus;
        livesBonus[msg.sender] = _livesBonus;
        pointsBonus[msg.sender] = _pointsBonus;
        speedBonusTr[msg.sender] = _speedBonusTr;
        livesBonusTr[msg.sender] = _livesBonusTr;
        pointsBonusTr[msg.sender] = _pointsBonusTr;
        weaponOil[msg.sender] = _weaponOil;
        weaponThunder[msg.sender] = _weaponThunder;
        weaponBomb[msg.sender] = _weaponBomb;
        earnPendingPVE[msg.sender] += _earnPendingPVE;
        ++nonce[msg.sender];
        emit SaveScore(msg.sender, _earnPendingPVE);
        return true;
    }

    /// @dev PVE claim function linked to earn supply with a 24hr lock (This is a user earn mechanic)
    /// @notice Claim PVE earn
    /// @param _earnPendingPVE The amount to claim
    /// @param _sig The signature from the authorization wallet
    /// @return true if claim is successful
    function claimPVEEarn(uint256 _earnPendingPVE, bytes memory _sig) external nonReentrant() returns (bool) {
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _earnPendingPVE + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        require(claimTimerPVE[msg.sender] >= 1 days || claimTimerPVE[msg.sender] == 0, "You've already claimed today!");
        require(_earnPendingPVE <= earnPendingPVE[msg.sender], "Not enough earnings to do that");
        require(scholarshipBool[msg.sender] == false, "Scholarship active");
        require(_earnPendingPVE <= pveEarnCap, "Earn is over earn cap");
        ++nonce[msg.sender];
        claimTimerPVE[msg.sender] = block.timestamp;
        earnPendingPVE[msg.sender] -= _earnPendingPVE;
        earnTotalPVE[msg.sender] += _earnPendingPVE;
        _token.claim(msg.sender, uint256(_earnPendingPVE));
        emit ClaimedPVE(msg.sender, uint256(_earnPendingPVE));
        return true;
    }

    /// @dev Allows user to claim pve earn once every 24 hours
    /// @notice Check if you can claim your PVE earnings
    /// @return bool Checks if the time has past 24 hours, returns true or false
    function earnCheckPVE(address _wallet) external view returns (bool){
        if ((block.timestamp >= (claimTimerPVE[_wallet] + 1 days)) || claimTimerPVE[_wallet] == 0) {
            return true;
        } else {
            return false;
        }
    }

    /// @dev Only admin can changes user access to the OG perk area in game
    /// @notice Changing OG User Perk
    /// @param _wallet The address to change the OG User Perk of
    /// @return true if successful
    function changeOGUserPerk(address _wallet) external nonReentrant() onlyOwner() returns (bool) {
        ogUserPerk[_wallet] = true;
        emit ChangeOGUserPerk(_wallet);
        return true;
    }

    /// @dev Shop buy functions

    /// @notice Buying surfcoinz (This is a burn mechanic)
    /// @param _amount The amount of tokens to send to the dev wallet
    /// @param _surfcoinz The surfcoinz of the address
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function buySurfcoinz(uint256 _amount, uint256 _surfcoinz, bytes memory _sig) external nonReentrant() returns (bool) {
        require(_amount == shopItemPrice, "Value not equal to amount");
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _surfcoinz + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        _token.burn(msg.sender, _amount);
        surfCoinz[msg.sender] = _surfcoinz;
        surfCoinz[msg.sender] += 20000;
        emit BuySurfcoinz(msg.sender, _amount);
        return true;
    }

    /// @notice Change speed amount
    /// @param _amountone The amount to set the bonus to
    /// @param _amounttwo The amount of time remaining on the bonus
    /// @param _surfcoinz The surfcoinz of the address
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function changeSpeedBonus(uint256 _amountone, uint256 _amounttwo, uint256 _surfcoinz, bytes memory _sig) external nonReentrant() returns (bool) {
        require(surfCoinz[msg.sender] >= 1000, "Not enough Surfoinz");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _surfcoinz + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        speedBonus[msg.sender] = _amountone;
        speedBonusTr[msg.sender] = _amounttwo;
        surfCoinz[msg.sender] = _surfcoinz;
        surfCoinz[msg.sender] -= 1000;
        emit BuyShopItem(msg.sender, 1000);
        return true;
    }

    /// @notice Change lives amount
    /// @param _amountone The amount to set the bonus to
    /// @param _amounttwo The amount of time remaining on the bonus
    /// @param _surfcoinz The surfcoinz of the address
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function changeLivesBonus(uint256 _amountone, uint256 _amounttwo, uint256 _surfcoinz, bytes memory _sig) external nonReentrant() returns (bool) {
        require(surfCoinz[msg.sender] >= 1000, "Not enough Surfoinz");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _surfcoinz + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        livesBonus[msg.sender] = _amountone;
        livesBonusTr[msg.sender] = _amounttwo;
        surfCoinz[msg.sender] = _surfcoinz;
        surfCoinz[msg.sender] -= 1000;
        emit BuyShopItem(msg.sender, 1000);
        return true;
    }

    /// @notice Change points bonus
    /// @param _amountone The amount to set the bonus to
    /// @param _amounttwo The amount of time remaining on the bonus
    /// @param _surfcoinz The surfcoinz of the address
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function changePointsBonus(uint256 _amountone, uint256 _amounttwo, uint256 _surfcoinz, bytes memory _sig) external nonReentrant() returns (bool) {
        require(surfCoinz[msg.sender] >= 1000, "Not enough Surfoinz");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _surfcoinz + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        pointsBonus[msg.sender] = _amountone;
        pointsBonusTr[msg.sender] = _amounttwo;
        surfCoinz[msg.sender] = _surfcoinz;
        surfCoinz[msg.sender] -= 1000;
        emit BuyShopItem(msg.sender, 1000);
        return true;
    }

    /// @notice Change oil amount (This is a burn mechanic)
    /// @param _amount The amount of tokens to send to the dev wallet
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function changeOil(uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        require(_amount == shopItemPrice, "Value not equal to amount");
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        _token.burn(msg.sender, _amount);
        weaponOil[msg.sender] = 5;
        emit BuyWeapons(msg.sender, shopItemPrice);
        return true;
    }

    /// @notice Change thunder amount (This is a burn mechanic)
    /// @param _amount The amount of tokens to send to the dev wallet
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function changeThunder(uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        require(_amount == shopItemPrice, "Value not equal to amount");
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        _token.burn(msg.sender, _amount);
        weaponThunder[msg.sender] = 5;
        emit BuyWeapons(msg.sender, shopItemPrice);
        return true;
    }

    /// @notice Change bomb amount (This is a burn mechanic)
    /// @param _amount The amount of tokens to send to the dev wallet
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function changeBomb(uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        require(_amount == shopItemPrice, "Value not equal to amount");
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        _token.burn(msg.sender, _amount);
        weaponBomb[msg.sender] = 5;
        emit BuyWeapons(msg.sender, shopItemPrice);
        return true;
    }

    /// @notice Claim free weapon bonus (This is an OGUser perk obtained from purchasing a chainsafe marketplace nft)
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function claimWeaponBonus(bytes memory _sig) external nonReentrant() returns (bool) {
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        require(claimTimerBonuses[msg.sender] >= 1 days || claimTimerBonuses[msg.sender] == 0, "You've already claimed today!");
        require(ogUserPerk[msg.sender] == true, "You don't have the OG user perk!");
        claimTimerBonuses[msg.sender] = block.timestamp;
        ++nonce[msg.sender];
        weaponBomb[msg.sender] = 5;
        weaponThunder[msg.sender] = 5;
        weaponOil[msg.sender] = 5;
        return true;
    }

    /// @notice Claim free item bonus (This is an OGUser perk obtained from purchasing a chainsafe marketplace nft)
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function claimItemBonus(bytes memory _sig) external nonReentrant() returns (bool) {
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        require(claimTimerBonuses[msg.sender] >= 1 days || claimTimerBonuses[msg.sender] == 0, "You've already claimed today!");
        require(ogUserPerk[msg.sender] == true, "You don't have the OG user perk!");
        claimTimerBonuses[msg.sender] = block.timestamp;
        ++nonce[msg.sender];
        speedBonus[msg.sender] = 1;
        speedBonusTr[msg.sender] = 60;
        livesBonus[msg.sender] = 1;
        livesBonusTr[msg.sender] = 60;
        pointsBonus[msg.sender] = 1;
        pointsBonusTr[msg.sender] = 60;
        return true;
    }

    /// @notice Claim free surfcoin bonus (This is an OGUser perk obtained from purchasing a chainsafe marketplace nft)
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function claimSurfcoinBonus(bytes memory _sig) external nonReentrant() returns (bool) {
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        require(claimTimerBonuses[msg.sender] >= 1 days || claimTimerBonuses[msg.sender] == 0, "You've already claimed today!");
        require(ogUserPerk[msg.sender] == true, "You don't have the OG user perk!");
        claimTimerBonuses[msg.sender] = block.timestamp;
        ++nonce[msg.sender];
        surfCoinz[msg.sender] += 5000;
        return true;
    }

    /// @dev Staking functions

    /// @notice Adding stake (This is a developer earn mechanic)
    /// @param _amount The amount of stake to add
    /// @param _sig The signature from the authorization wallet
    /// @return bool True if adding stake is successful
    function addStake(uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        require ((_amount + stakeTotal[msg.sender]) <= stakingCap, "Staking amount over the allowed cap");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _amount + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        timeStaked[msg.sender] = block.timestamp;
        uint devAmount10 = _amount * 10/100;
        uint stakeAmount90 = _amount * 90/100;
        stakeTotal[msg.sender] += stakeAmount90;
        _token.lotteryStakeBurn(msg.sender, _amount);
        _token.lotteryStakeMint(devWallet, devAmount10);
        _token.increaseEarnSupply(msg.sender, int256(stakeAmount90));
        emit AddStake(msg.sender, _amount);
        return true;
    }

    /// @notice Removing stake
    /// @param _amount The amount of stake to remove
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function removeStake(uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        require(_amount <= stakeTotal[msg.sender], "Not enough stake to do that");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _amount + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        timeStaked[msg.sender] = 0;
        stakeTotal[msg.sender] -= _amount;
        _token.decreaseEarnSupply(msg.sender, int256(_amount));
        _token.lotteryStakeMint(msg.sender, _amount);
        emit RemovedStake(msg.sender, uint256(_amount));
        return true;
    }

    /// @dev PVP functions

    /// @notice PVP and wager tokens
    /// @param _amount The amount of tokens being wagered
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function setPvpWager(uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _amount + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(_amount <= pvpCap, "Amount over PVP Cap");
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        ++nonce[msg.sender];
        pvpWager[msg.sender] = _amount;
        emit SetPVPWager(msg.sender, _amount);
        return true;
    }

    /// @notice PVP and wager tokens
    /// @param _opponent The address of the challenging opponent
    /// @param _amount The amount of tokens being wagered
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function acceptPvpWager(address _opponent, uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _amount + (uint256(uint160(msg.sender))/1e40) + (uint256(uint160(_opponent))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        ++nonce[msg.sender];
        pvpWager[msg.sender] = _amount;
        weaponBomb[msg.sender] = 0;
        weaponThunder[msg.sender] = 0;
        weaponOil[msg.sender] = 0;
        emit AcceptPVPWager(msg.sender, _opponent, _amount);
        return true;
    }

    /// @notice Claim PVP Winnings, 10% to dev wallet (This is a developer earn mechanic)
    /// @param _opponent The address of the challenging opponent
    /// @param _amount The amount of tokens being wagered
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function pvpWagerClaim(address _opponent, uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        require(pvpWager[msg.sender] == _amount, "Wager amount wrong");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _amount + (uint256(uint160(msg.sender))/1e40) + (uint256(uint160(_opponent))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        pvpWager[msg.sender] = 0;
        pvpWager[_opponent] = 0;
        weaponBomb[msg.sender] = 0;
        weaponThunder[msg.sender] = 0;
        weaponOil[msg.sender] = 0;
        uint256 devAmount10 = _amount * 10/100;
        uint256 claimAmount90 = _amount * 90/100;
        _token.gameTokenTransfer(_opponent, devWallet, devAmount10);
        _token.gameTokenTransfer(_opponent, msg.sender, claimAmount90);
        emit ClaimedPVPWinnings(msg.sender, _opponent, _amount);
        return true;
    }

    /// @dev Scholarship functions

    /// @notice Changing Scholarships
    /// param _scholarshipManager The scholarship manager
    /// param _scholar1 First scholar
    /// param _scholar2 Second scholar
    /// param _scholar3 Third scholar
    /// @return true if successful
    function changeScholar(address _scholar) external nonReentrant() returns (bool) {
        require(_scholar != msg.sender, "You can't add yourself as a manager");
        /// @dev stops users abusing the scholarship system by adding a 24 hour timer between scholar changes
        require(changeScholarTimer[msg.sender] >= 1 days || changeScholarTimer[msg.sender] == 0, "You need to wait 24 hours before changing scholars");
        /// @dev links scholar to managers wallet
        scholar[msg.sender] = _scholar;
        /// @dev changes scholar bool if defaults are changed or removed in game
        if (_scholar != address(0)) {
            scholarBool[msg.sender] = true;
            changeScholarTimer[msg.sender] = block.timestamp;
        } else {
            scholarBool[msg.sender] = false;
        }
        emit ChangeScholar(msg.sender, _scholar);
        return true;
    }

    /// @notice Changing Scholarship Manager
    /// param _scholarshipManager The scholarship manager
    /// @return true if successful
    function changeScholarManager(address _scholarshipManager) external nonReentrant() returns (bool) {
        require(_scholarshipManager != msg.sender, "You can't add yourself as a manager");
        require(scholar[_scholarshipManager] == msg.sender || _scholarshipManager == address(0), "Manager doesn't have you listed as a scholar");
        scholarshipManager[msg.sender] = _scholarshipManager;
        /// @dev changes scholarship bool if defaults are changed or removed in game
        if (_scholarshipManager != address(0)) {
            scholarshipBool[msg.sender] = true;
        } else {
            scholarshipBool[msg.sender] = false;
        }
        emit ChangeScholarManager(msg.sender, _scholarshipManager);
        return true;
    }

    /// @dev Used when scholarship is active when saving score in game
    /// @notice Save your scores and earn for you and your manager
    /// @param _surfcoinz The surfcoinz of the address
    /// @param _speedBonus The speed bonus of the address
    /// @param _livesBonus The lives bonus of the address
    /// @param _pointsBonus The points bonus of the address
    /// @param _speedBonusTr The speed bonus time remaining of the address
    /// @param _livesBonusTr The lives bonus time remaining of the address
    /// @param _pointsBonusTr The points bonus time remaining of the address
    /// @param _weaponOil The weapon oil of the address
    /// @param _weaponThunder The weapon thunder of the address
    /// @param _weaponBomb The weapon bombs of the address
    /// @param _earnPendingPVE The earn pending PVE of the address
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function saveScoreScholarship(
        uint256 _surfcoinz,
        uint256 _speedBonus,
        uint256 _livesBonus,
        uint256 _pointsBonus,
        uint256 _speedBonusTr,
        uint256 _livesBonusTr,
        uint256 _pointsBonusTr,
        uint256 _weaponOil,
        uint256 _weaponThunder,
        uint256 _weaponBomb,
        uint256 _earnPendingPVE,
        bytes memory _sig
    )
        external
        nonReentrant()
        returns (bool)
    {
        require(scholarshipBool[msg.sender] == true, "Scholarship not active");
        require(scholarBool[msg.sender] == false, "You have a scholar");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _earnPendingPVE + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        surfCoinz[msg.sender] = _surfcoinz;
        speedBonus[msg.sender] = _speedBonus;
        livesBonus[msg.sender] = _livesBonus;
        pointsBonus[msg.sender] = _pointsBonus;
        speedBonusTr[msg.sender] = _speedBonusTr;
        livesBonusTr[msg.sender] = _livesBonusTr;
        pointsBonusTr[msg.sender] = _pointsBonusTr;
        weaponOil[msg.sender] = _weaponOil;
        weaponThunder[msg.sender] = _weaponThunder;
        weaponBomb[msg.sender] = _weaponBomb;
        earnPendingScholarship[msg.sender] += _earnPendingPVE;
        ++nonce[msg.sender];
        emit SaveScore(msg.sender, _earnPendingPVE);
        return true;
    }

    /// @dev Scholarship claim function with a 24hr lock (This is a user earn mechanic)
    /// @notice Claim scholarhip earn
    /// @param _managerWallet The manager wallet of the address
    /// @param _earnPendingScholarship The amount being claimed
    /// @param _sig The signature from the authorization wallet
    /// @return true if claim is successful
    function claimScholarshipEarn(address _managerWallet, uint256 _earnPendingScholarship, bytes memory _sig) external nonReentrant() returns (bool) {
        require(scholarshipBool[msg.sender] == true, "Scholarship not active");
        require(scholarBool[msg.sender] == false, "You have a scholar");
        require(scholarshipManager[msg.sender] == _managerWallet,"This isn't your scholarship manager");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _earnPendingScholarship + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        require(claimTimerScholar[msg.sender] >= 1 days || claimTimerScholar[msg.sender] == 0, "You've already claimed today!");
        require(_earnPendingScholarship <= earnPendingScholarship[msg.sender], "Not enough earnings to do that");
        require(_earnPendingScholarship <= scholarshipEarnCap, "Scholarship earn is over earn cap");
        ++nonce[msg.sender];
        earnPendingScholarship[msg.sender] -= _earnPendingScholarship;
        earnTotalScholarship[msg.sender] += _earnPendingScholarship;
        claimTimerScholar[msg.sender] = block.timestamp;
        _token.scholarClaim(msg.sender, uint256(_earnPendingScholarship));
        _token.scholarClaim(_managerWallet, uint256(_earnPendingScholarship));
        emit ClaimedScholarship(msg.sender, uint256(_earnPendingScholarship));
        emit ClaimedScholarship(_managerWallet, uint256(_earnPendingScholarship));
        return true;
    }

    /// @dev Allows user to claim scholarship earn once every 24 hours
    /// @param _wallet users wallet
    /// @return bool Checks if the time has past 24 hours, returns true or false
    function earnCheckScholar(address _wallet) external view returns (bool){
        if ((block.timestamp >= (claimTimerScholar[_wallet] + 1 days)) || claimTimerScholar[_wallet] == 0) {
            return true;
        } else {
            return false;
        }
    }

    /// @dev used for staking
    /// @param _wallet users wallet
    /// @return uint256 days a user has funds staked for
    function getTimeStakedDays(address _wallet) external view returns (uint256) {
        if (timeStaked[_wallet] == 0)
        {
            return 0;
        }
        else
        {
            uint timeNow = block.timestamp;
            uint timeStakedFor = (timeNow - timeStaked[_wallet]) / 60 / 60 / 24;
            return timeStakedFor;
        }
    }

    /// @dev used for security
    /// @param _wallet users wallet
    /// @return uint256 used for user wallet security
    function getWalletInt(address _wallet) external pure returns (uint256) {
        return uint256(uint160(_wallet))/1e40;
    }

    /// @dev Used by owner to change shop prices
    /// @param _amount Price amount to change to
    /// @return true if successful
    function changeShopPrices(uint256 _amount) external nonReentrant() onlyOwner() returns (bool) {
        shopItemPrice = _amount*1e18;
        return true;
    }

    /// @dev Used by owner to change pve earn cap
    /// @param _amount Cap amount to change to
    /// @return true if successful
    function changePveEarnCap(uint256 _amount) external nonReentrant() onlyOwner() returns (bool) {
        pveEarnCap = _amount*1e18;
        return true;
    }

    /// @dev Used by owner to change scholarship pve earn cap
    /// @param _amount Cap amount to change to
    /// @return true if successful
    function changeScholarshipEarnCap(uint256 _amount) external nonReentrant() onlyOwner() returns (bool) {
        scholarshipEarnCap = _amount*1e18;
        return true;
    }

    /// @dev Used by owner to change staking cap
    /// @param _amount Cap amount to change to
    /// @return true if successful
    function changeStakingCap(uint256 _amount) external nonReentrant() onlyOwner() returns (bool) {
        stakingCap = _amount*1e18;
        return true;
    }

    /// @dev Used by owner to change pvp cap
    /// @param _amount Cap amount to change to
    /// @return true if successful
    function changePvpCap(uint256 _amount) external nonReentrant() onlyOwner() returns (bool) {
        pvpCap = _amount*1e18;
        return true;
    }

    /// @dev Used by owner to change dev wallet 
    /// @param _wallet Dev wallet to change to
    /// @return true if successful
    function changeDevWallet(address _wallet) external nonReentrant() onlyOwner() returns (bool) {
        devWallet = _wallet;
        return true;
    }

    /// @dev Used by owner to change auth wallet 
    /// @param _wallet Auth wallet to change to
    /// @return true if successful
    function changeAuthWallet(address _wallet) external nonReentrant() onlyOwner() returns (bool) {
        authWallet = _wallet;
        return true;
    }

    /// @dev Grouped getter functions to reduce blockchain call load

    /// @dev User Bonus stats
    /// @return array of user bonus stats
    function bonusStats(address _wallet) external view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        return (
            speedBonus[_wallet],
            speedBonusTr[_wallet],
            livesBonus[_wallet],
            livesBonusTr[_wallet],
            pointsBonus[_wallet],
            pointsBonusTr[_wallet]
        );
    }

    /// @dev User Weapon stats
    /// @return array of user weapon stats
    function weaponStats(address _wallet) external view returns (uint256, uint256, uint256, uint256, bool) {
        return (
            weaponOil[_wallet],
            weaponThunder[_wallet],
            weaponBomb[_wallet],
            uint256(uint160(_wallet))/1e40,
            ogUserPerk[_wallet]
        );
    }

    /// @dev User Scholar stats
    /// @return array of user scholarship stats
    function scholarStats(address _wallet) external view returns (address, bool, address, bool, uint256, uint256, uint256) {
        return (
            scholarshipManager[_wallet],
            scholarshipBool[_wallet],
            scholar[_wallet],
            scholarBool[_wallet],
            earnPendingScholarship[_wallet],
            earnTotalScholarship[_wallet],
            claimTimerScholar[_wallet]
        );
    }

    /// @dev User Earn stats
    /// @return array of user earn stats
    function earnStats(address _wallet) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, string memory) {
        return (
            claimTimerPVE[_wallet],
            earnPendingPVE[_wallet],
            earnTotalPVE[_wallet],
            timeStaked[_wallet],
            stakeTotal[_wallet],
            surfCoinz[_wallet],
            userName[_wallet]
        );
    }

    /// @dev Stats Contracts Caps
    /// @return array of stats contract caps
    function statsCaps() external view returns (uint256, uint256, uint256, uint256, uint256) {
        return (
            pveEarnCap,
            scholarshipEarnCap,
            shopItemPrice,
            stakingCap,
            pvpCap
        );
    }

    /// @dev Used for authentication to check if values came from inside the CSF game following solidity standards
    function VerifySig(address _signer, string memory _message, bytes memory _sig) external pure returns (bool) {
        bytes32 messageHash = getMessageHash(_message);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        return recover(ethSignedMessageHash, _sig) == _signer;
    }

    function getMessageHash(string memory _message) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_message));
    }

    function getEthSignedMessageHash(bytes32 _messageHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32",_messageHash));
    }

    function recover(bytes32 _ethSignedMessageHash, bytes memory _sig) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = _split(_sig);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function _split (bytes memory _sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(_sig.length == 65, "Invalid signature length");
        assembly{
            r := mload(add(_sig, 32))
            s := mload(add(_sig, 64))
            v := byte(0, mload(add(_sig, 96)))
        }
    }
}