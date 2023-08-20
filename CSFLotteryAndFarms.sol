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

/// @title CSF Lottery & Farms Contract
/// @author Sneakz
/// @notice This contract holds functions used for the Crypto Surferz lottery & farms used in the game at https://www.cryptosurferz.com/
/// @dev All function calls are tested and have been implemented on the Crypto Surferz Game complete with earn and burn mechanics
/// @dev Make sure this contract has admin role rights from the token contract to enable minting on claims

contract CSFLotteryAndFarms is ReentrancyGuard, Ownable {
    /// @dev Initializes the ERC20 token and lottery timer
    CSFToken immutable _token;
    uint256 lotteryTimer;

    /// @dev Constructor sets token to be used, input the CSF token address here on deployment
    constructor (CSFToken token) {
        _token = token;
        lotteryTimer = block.timestamp;
    }

    /// @dev Lottery variables
    uint256 constant MAX_LOTTERY_TICKETS = 200;
    /// @dev Lottery winners
    address public lotteryWinner1;
    address public lotteryWinner2;
    address public lotteryWinner3;
    /// @dev Pot and transfer amounts
    uint256 public potAmount;
    uint256 public lastPotAmount;
    uint256 public totalLotteryTickets = 0;
    /// @dev Ticket prices & Max lottery tickets (can be changed by owner as token price fluctuates)
    uint256 public ticketPrice = 500000*1e18;
    uint256 public earnOrBurnPrice = 1000000*1e18;
    /// @dev Ticket buyers and owners
    address[] ticketBuyers;
    uint[] idsOwned;
    /// @dev Wallet that tokens go to on purchases
    address devWallet = 0x76131D0bA1e061167Df4ED539bA9CF87aC58a323;
    /// @dev wallet that auth signatures come from
    address authWallet = 0xbee02166dd883D911b614990957b1726f92779d9;

    /// @dev Farm variables
    /// @dev Farm upgrade price (can be changed by owner as token price fluctuates)
    uint256 public farmUpgradePrice = 1000000*1e18;
    uint256 public farmEarnCap = 500000*1e18;

    /// @dev Lottery mappings
    /// @dev Total lottery tickets
    mapping(address => uint256) public lotteryTickets;
    /// @dev The current owner of each ticket
    mapping(uint256 => address) public ticketToOwner;
    /// @dev Friend mappings
    mapping(address => address) public friend1;
    mapping(address => address) public friend2;
    mapping(address => address) public friend3;
    mapping(address => address) public friend4;
    /// @dev Farm mappings
    mapping(address => uint256) public claimTimerFarm;
    mapping(address => uint256) public farmTimer;
    mapping(address => uint256) public earnPendingFarm;
    mapping(address => uint256) public earnTotalFarm;
    mapping(address => uint256) public treeFarmLevel;
    mapping(address => uint256) public shipFarmLevel;
    mapping(address => uint256) public coinFarmLevel;
    /// @dev Nonce to stop cheaters
    mapping(address => uint256) public nonce;
    
    /// @dev Lottery events
    event BuyLotteryTickets(address indexed wallet, uint256 amount);
    event LotteryWinner(address indexed winner, uint256 amount); 
    /// @dev Farm events
    event ClaimedFarm(address indexed wallet, uint256 amount);
    event ChangeFarmTimer(address indexed wallet, uint256 timeStamp);
    event ChangeFarmPlotLevel(address indexed wallet, uint256 amount);
    event ChangeFriend(address indexed wallet, address friendWallet1, address friendWallet2, address friendWallet3, address friendWallet4);

    /// @dev Lottery functions

    /// @notice Buys lottery tickets and increases the lottery pot. Also checks the lottery timer, if timer is up then distribute the lottery (This is a developer earn mechanic)
    /// @param _tickets The amount of tickets being purchased
    /// @param _sig The signature from the authorization wallet
    /// @return bool True if success, false if failed
    function buyTickets(uint256 _tickets, bytes memory _sig) external nonReentrant() returns (bool) {
        require(_tickets <= 10, "You can't buy more than 10 tickets at once");
        uint256 _amount = ticketPrice*_tickets;
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        /// @dev checks if the time between deployment of the contract or last lottery time and now is over 7 days
        uint256 nowTime = block.timestamp-lotteryTimer;
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _tickets + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        /// @dev if time is over 7 days or 200 tickets (stops the array growing too large with the for loop iterations) then declare the winners and reset the lottery timer
        if (nowTime >= 7 days || totalLotteryTickets >= MAX_LOTTERY_TICKETS) {
            /// @dev resets the lottery timer and chooses winners
            lotteryTimer = block.timestamp;
            uint256 one = (totalLotteryTickets/2);
            lotteryWinner1 = ticketToOwner[one];
            /// @dev if the chosen lottery winner is null, send tokens to the dev wallet instead
            if (lotteryWinner1 == address(0)) {
                lotteryWinner1 = devWallet;
            }
            uint256 two = (totalLotteryTickets/3);
            lotteryWinner2 = ticketToOwner[two];
            /// @dev if the chosen lottery winner is null, send tokens to the dev wallet instead
            if (lotteryWinner2 == address(0)) {
                lotteryWinner2 = devWallet;
            }
            uint256 three = (totalLotteryTickets/4);
            lotteryWinner3 = ticketToOwner[three];
            /// @dev if the chosen lottery winner is null, send tokens to the dev wallet instead
            if (lotteryWinner3 == address(0)) {
                lotteryWinner3 = devWallet;
            }
            uint devAmount10 = potAmount*10/100;
            uint potAmount90 = potAmount*90/100;
            lastPotAmount = potAmount90/3;
            
            /// @dev Using game token transfer instead of transferFrom to avoid double gas prompt on approve
            _token.lotteryStakeMint(lotteryWinner1, lastPotAmount);
            emit LotteryWinner(lotteryWinner1, lastPotAmount);
            _token.lotteryStakeMint(lotteryWinner2, lastPotAmount);
            emit LotteryWinner(lotteryWinner2, lastPotAmount);
            _token.lotteryStakeMint(lotteryWinner3, lastPotAmount);
            emit LotteryWinner(lotteryWinner3, lastPotAmount);
            /// @dev 10% of each pot is sent to the developer wallet to be used for tokenmoics as needed
            _token.lotteryStakeMint(devWallet, devAmount10);
            emit LotteryWinner(devWallet, devAmount10);

            /// @dev Sets all tickets to 0
            for (uint256 i=0; i< ticketBuyers.length ; ++i) {
            lotteryTickets[ticketBuyers[i]] = 0;
            }
            for (uint256 i=0; i< idsOwned.length ; ++i) {
            /// @dev Owner list set back to dev wallet to prevent double ups
            ticketToOwner[idsOwned[i]] = devWallet;
            }
            
            /// @dev Tickets and pot amount reset to 0
            totalLotteryTickets = 0;
            potAmount = 0;
        }
        _token.lotteryStakeBurn(msg.sender, _amount);
        potAmount += _amount;
        lotteryTickets[msg.sender] += _tickets;
        uint256 max = totalLotteryTickets + _tickets;
        for(uint256 i = totalLotteryTickets; i < max;) {
            unchecked{
                ++i;
            }
        ticketToOwner[i] = msg.sender;
        idsOwned.push(i);
        }
        totalLotteryTickets += _tickets;
        ticketBuyers.push(msg.sender);
        emit BuyLotteryTickets(msg.sender, _amount);
        return true;
    }

    /// @dev Farm functions

    /// @dev Farm claim function linked to earn supply with a 24hr lock (This is a user earn mechanic)
    /// @notice Claim farm earn
    /// @param _earnPendingFarm The amount to claim
    /// @param _sig The signature from the authorization wallet
    /// @return true if claim is successful
    function claimFarmEarn(uint256 _earnPendingFarm, bytes memory _sig) external nonReentrant() returns (bool) {
        require(claimTimerFarm[msg.sender] >= 1 days || claimTimerFarm[msg.sender] == 0, "You've already claimed today!");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _earnPendingFarm + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        require(_earnPendingFarm <= earnPendingFarm[msg.sender], "Not Enough Farm Earn");
        require(_earnPendingFarm <= farmEarnCap, "Farm earn is over earn cap");
        ++nonce[msg.sender];
        earnPendingFarm[msg.sender] -= _earnPendingFarm;
        earnTotalFarm[msg.sender] += _earnPendingFarm;
        claimTimerFarm[msg.sender] = block.timestamp;
        _token.claim(msg.sender, uint256(_earnPendingFarm));
        emit ClaimedFarm(msg.sender, uint256(_earnPendingFarm));
        return true;
    }

    /// @dev Farm upgrade functions used to upgrade farm levels in game

    /// @notice Upgrading tree farm level (This is a burn mechanic)
    /// @param _amount The amount of tokens to send to the dev wallet
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function changeTreeFarmLevel(uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        require(_amount == farmUpgradePrice, "Value not equal to amount");
        require(treeFarmLevel[msg.sender] <= 2, "Farm level max");
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        _token.burn(msg.sender, _amount);
        ++treeFarmLevel[msg.sender];
        emit ChangeFarmPlotLevel(msg.sender, treeFarmLevel[msg.sender]);
        return true;
    }

    /// @notice Upgrading ship farm level (This is a burn mechanic)
    /// @param _amount The amount of tokens to send to the dev wallet
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function changeShipFarmLevel(uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        require(_amount == farmUpgradePrice, "Value not equal to amount");
        require(shipFarmLevel[msg.sender] <= 2, "Farm level max");
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        _token.burn(msg.sender, _amount);
        ++shipFarmLevel[msg.sender];
        emit ChangeFarmPlotLevel(msg.sender, shipFarmLevel[msg.sender]);
        return true;
    }

    /// @notice Upgrading coin farm level (This is a burn mechanic)
    /// @param _amount The amount of tokens to send to the dev wallet
    /// @param _sig The signature from the authorization wallet
    /// @return true if successful
    function changeCoinFarmLevel(uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        require(_amount == farmUpgradePrice, "Value not equal to amount");
        require(coinFarmLevel[msg.sender] <= 2, "Farm level max");
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        _token.burn(msg.sender, _amount);
        ++coinFarmLevel[msg.sender];
        emit ChangeFarmPlotLevel(msg.sender, coinFarmLevel[msg.sender]);
        return true;
    }

    /// @dev Changes the farm timer when a user earns on someone elses farm and updates earnings
    /// @notice Calculates farm earnings
    /// @param _theFarmsWallet The address of the farm time being changed
    /// @param _earnings The earnings to add
    /// @return true if successful
    function changeFarmTimer(address _theFarmsWallet, uint256 _earnings, bytes memory _sig) external nonReentrant() returns (bool) {
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _earnings + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        farmTimer[_theFarmsWallet] = block.timestamp;
        ++nonce[msg.sender];
        earnPendingFarm[msg.sender] += _earnings;
        if (_theFarmsWallet != msg.sender)
        {
            earnPendingFarm[_theFarmsWallet] += _earnings;
        }
        emit ChangeFarmTimer(_theFarmsWallet, block.timestamp);
        return true;
    }

    /// @dev This timer allows farms to spawn collectibles every 30 minutes
    /// @notice Check the timer before your farm respawns collectibles
    /// @param _theFarmsWallet The address to check
    /// @return bool Checks if the time has past 30 minutes, returns true or false
    function checkTimerFarm(address _theFarmsWallet) external view returns (bool) {
        if ((block.timestamp >= (farmTimer[_theFarmsWallet] + 30 minutes)) || farmTimer[_theFarmsWallet] == 0) {
            return true;
        } else {
            return false;
        }
    }

    /// @notice Change friends list if you want to go to a users farm easily from the farm menu or chat
    /// @param _friend1 The friend number to alter
    /// @param _friend2 The friend number to alter
    /// @param _friend3 The friend number to alter
    /// @param _friend4 The friend number to alter
    function changeFriend(address _friend1, address _friend2, address _friend3, address _friend4) external nonReentrant() returns (bool) {
        friend1[msg.sender] = _friend1;
        friend2[msg.sender] = _friend2;
        friend3[msg.sender] = _friend3;
        friend4[msg.sender] = _friend4;
        emit ChangeFriend(msg.sender, _friend1, _friend2, _friend3, _friend4);
        return true;
    }

    /// @notice Game mode start with a higher earn rate or cool items with a burn mechanic if you lose (This is a burn mechanic)
    function earnOrBurn() external nonReentrant() returns (bool) {
        _token.burn(msg.sender, earnOrBurnPrice);
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

    /// @dev Token price change functions

    /// @dev Used to change price on earn or burn game mode as token price fluctuates
    /// @param _amount Price amount to change to
    /// @return true if successful
    function changeEarnOrBurnPrice(uint256 _amount) external nonReentrant() onlyOwner() returns (bool) {
        earnOrBurnPrice = _amount*1e18;
        return true;
    }

    /// @dev Used to change price on lottery tickets as token price fluctuates
    /// @param _amount Price amount to change to
    /// @return true if successful
    function changeLotteryTicketPrice(uint256 _amount) external nonReentrant() onlyOwner() returns (bool) {
        ticketPrice = _amount*1e18;
        return true;
    }

    /// @dev Used to change price on farm upgrades as token price fluctuates
    /// @param _amount Price amount to change to
    /// @return true if successful
    function changeFarmUpgradePrice(uint256 _amount) external nonReentrant() onlyOwner() returns (bool) {
        farmUpgradePrice = _amount*1e18;
        return true;
    }

    /// @dev Used to change farm earn cap as token price fluctuates
    /// @param _amount Cap amount to change to
    /// @return true if successful
    function changeFarmEarnCap(uint256 _amount) external nonReentrant() onlyOwner() returns (bool) {
        farmEarnCap = _amount*1e18;
        return true;
    }

    /// @dev Grouped getter functions to reduce blockchain call load

    /// @dev Lottery stats
    /// @return array of user lottery stats
    function lotteryStats(address _wallet) external view returns (uint256, uint256, uint256, address, address, address, uint256) {
        return (
            lotteryTickets[_wallet],
            potAmount,
            lastPotAmount,
            lotteryWinner1,
            lotteryWinner2,
            lotteryWinner3,
            totalLotteryTickets
        );
    }
  
    /// @dev Farm stats
    /// @return array of user farm stats
    function farmStats(address _wallet) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        return (
            claimTimerFarm[_wallet],
            farmTimer[_wallet],
            earnPendingFarm[_wallet],
            earnTotalFarm[_wallet],
            treeFarmLevel[_wallet],
            shipFarmLevel[_wallet],
            coinFarmLevel[_wallet]
        );
    }

    /// @dev Friend stats
    /// @return array of user friend stats
    function friendStats(address _wallet) external view returns (address, address, address, address) {
        return (friend1[_wallet], friend2[_wallet], friend3[_wallet], friend4[_wallet]);
    }

    /// @dev Lottery Contracts Caps
    /// @return array of lottery contract caps
    function lotteryCaps() external view returns (uint256, uint256, uint256, uint256) {
        return (
            ticketPrice,
            farmUpgradePrice,
            farmEarnCap,
            earnOrBurnPrice
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