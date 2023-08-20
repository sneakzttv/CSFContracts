// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "/contracts/CSFToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//  $$$$$$\   $$$$$$\  $$$$$$$$\ 
// $$  __$$\ $$  __$$\ $$  _____|
// $$ /  \__|$$ /  \__|$$ |      
// $$ |      \$$$$$$\  $$$$$\    
// $$ |       \____$$\ $$  __|   
// $$ |  $$\ $$\   $$ |$$ |      
// \$$$$$$  |\$$$$$$  |$$ |      
//  \______/  \______/ \__|  

/// @title CSF NFT Boards Contract
/// @author Sneakz
/// @notice This contract holds functions used for the Crypto Surferz NFT boards used in the game at https://www.cryptosurferz.com/
/// @dev All function calls are tested and have been implemented on the Crypto Surferz Game complete with earn and burn mechanics
/// @dev Make sure this contract has admin role rights from the token contract to enable NFT minting

contract CSFNFTBoards is ERC721, Ownable, ReentrancyGuard {
    /// @dev Initializes the ERC20 token
    CSFToken immutable _token;

    /// @dev Constructor sets token to be used and nft info, input the CSF token address here on deployment
    constructor(CSFToken token) ERC721("CSFNFTBoard", "CSFNFT") {
        _token = token;
        /// @dev creates the marketplace array
        nodes.push(Node(new bytes(0), 0, 0));
    }

    /// @dev Base URI for NFTBoard ipfs image
    string constant public BASE_URI = "https://ipfs.chainsafe.io/ipfs/";
    string constant public URI1 = "QmdW2tRdCw2YERvhzbMHn2qcaBHPMNo5ofsoo8q9q9N3Qe";
    string constant public URI2 = "QmWavwGJgqxMP38a6cxn9ehJASqdXNNcRT4YD7sa3dDMST";
    string constant public URI3 = "QmevuY959udKfEYXJvLZmVqiNFVe6KfqqxMRprYbtRhncP";
    string constant public URI4 = "QmbeE58Z8MT7thvzTbF6okxEdPoYhEWV5ZVVkrLPXxE6qb";
    string constant public URI5 = "QmSMKDJFT6Vvzx4XAYQ2huz1gH2NKfei44qhd74ny1Kur6";
    string constant public URI6 = "QmUR2N6Ln2XT6Dv3yEnGydmnp9ik65hVM6imEvigm3PVWM";
    /// @dev NFT Contract variables
    uint256 public globalboardListingCount = 0;
    /// @dev The total count of NFTs
    uint256 public totalNftCount = 0;
    /// @dev DbagDave timer
    uint256 public dbagDaveWeeklyEarnCapPercentage = 15;
    /// @dev NFTBoard prices
    uint256 public nftPrice = 500000*1e18;
    uint256 public upgradePrice = 1000000*1e18;
    uint256 nftId = 1;
    /// @dev Wallet that tokens go to on purchases
    address devWallet = 0x76131D0bA1e061167Df4ED539bA9CF87aC58a323;
    /// @dev wallet that auth signatures come from
    address authWallet = 0xbee02166dd883D911b614990957b1726f92779d9;

    /// @dev Contract mappings
    /// @dev Array of NFT IDs for an address
    mapping(address => uint256[]) public ownerNftIds;
    /// @dev Array for users listed NFT IDs
    mapping(address => uint256[]) public ownerListedNftIds;
    /// @dev Contract Mappings
    mapping(uint256 => uint256) public nodeListedNftId;
    mapping(uint256 => address) public boardApprovals;
    /// @dev Mapping of who owns what nftid
    mapping(uint256 => address) public boardToOwner;
    /// @dev Mapping of who owns what listed nftid
    mapping(uint256 => address) public listedBoardToOwner;
    /// @dev Total NFTs an address owns
    mapping(address => uint256) public ownerboardCount;
    /// @dev Amount of NFTboards an address has on the marketplace
    mapping(address => uint256) public ownerboardListingCount;
    /// @dev Total amount of NFTs that have been minted
    mapping(uint256 => uint256) public totalNfts;
    /// @dev Index mapping for moving array to the left for clean up
    mapping(uint256 => uint256) public indexOfAsset;
    /// @dev Mapping to check if an NFT ID is listed for auction on the marketplace
    mapping(uint256 => bool) public listedBool;
    /// @dev Amount an NFT ID is listed for
    mapping(uint256 => uint256) public listedAmount;
    /// @dev dbagdave mappings
    mapping(address => uint256) public dbagDavePaidAmount;
    mapping(address => uint256) public dbagDaveTimer;
    /// @dev NFTboard stats
    mapping(uint256 => uint256) public nameId;
    mapping(uint256 => uint256) public speed;
    mapping(uint256 => uint256) public weaponSlots;
    mapping(uint256 => uint256) public rarity;
    mapping(uint256 => uint256) public health;
    mapping(uint256 => uint256) lastTimeWasListed;
    /// @dev Nonce to stop cheaters
    mapping(address => uint256) public nonce;

    /// @dev Contract events
    event BuyNFT(address indexed wallet, uint256 indexed nftid, uint256 amount);
    event BuyListedNFT(address indexed wallet, address indexed buyer, uint256 indexed nftid, uint256 amount);
    event ListNFT(address indexed wallet, uint256 indexed nftid, uint256 amount);
    event CancelNFTListing(address indexed wallet, uint256 indexed nftid);
    event UpgradeNFT(address indexed wallet, uint256 indexed nftid, uint256 amount);
    event BurnNFT(address indexed wallet, address indexed burnAddress, uint256 indexed nftid);
    event PayDbagDave(address indexed wallet, uint256 amount);

    /// @dev Contract functions

    ///@dev required node stuff for doubly linked list
    struct Node {
        bytes data;
        uint256 prev;
        uint256 next;
    }

    ///@dev nodes[0].next is head, and nodes[0].prev is tail
    Node[] public nodes;

    ///@dev checks if node is valid
    function isValidNode(uint256 id) internal view returns (bool) {
        // 0 is a sentinel and therefore invalid.
        // A valid node is the head or has a previous node.
        return id != 0 && (id == nodes[0].next || nodes[id].prev != 0);
    }

    ///@dev used to encode node data from strings to put it into the node
    function encode(string memory _listedNftId, string memory _nameId, string memory _speed ,string memory _weaponSlots ,string memory _rarity ,string memory _health, string memory _listedAmount) external pure returns (bytes memory) {
        bytes memory encoded = abi.encode(_listedNftId, _nameId, _speed, _weaponSlots, _rarity, _health, _listedAmount);
        return encoded;
    }

    ///@dev used to decode node data to strings when getting data from the node
    function decode(bytes memory _encoded) external pure returns (string memory _listedNftId, string memory _nameId, string memory _speed ,string memory _weaponSlots ,string memory _rarity ,string memory _health, string memory _listedAmount) {
        return abi.decode(_encoded, (string, string, string, string, string, string, string));
    }
    
    /// @dev Add board to users array, used when purchasing a board (This is a developer earn mechanic)
    /// @notice Buy an NFT Board
    /// @param _rarity The rarity level of the NFT
    /// @param _nameId The name ID of the NFT
    /// @param _amount The amount of tokens to send to the dev wallet
    /// @param _sig The signature from the authorization wallet
    /// @return bool True if success, false if failed
    function addBoard(uint256 _rarity, uint256 _nameId, uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        require(_amount == nftPrice, "Value not equal to amount");
        require(_rarity <= 5, "Rarity wrong");
        require(_nameId <= 3, "Name wrong");
        require(ownerboardCount[msg.sender] <= 9, "You can only have 10 nfts at one time");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _rarity + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        _token.gameTokenTransfer(msg.sender, devWallet, _amount);
        ++nonce[msg.sender];
        boardToOwner[nftId] = msg.sender;
        listedBoardToOwner[nftId] = msg.sender;
        nameId[nftId] = _nameId;
        speed[nftId] = 0;
        weaponSlots[nftId] = 0;
        health[nftId] = 0;
        rarity[nftId] = _rarity;
        listedAmount[nftId] = 0;
        listedBool[nftId] = false;
        ownerboardCount[msg.sender] += 1;
        /// @dev sets legendary names for Nft boards
        if (_rarity == 5) {
            if (_nameId == 1) {
                _nameId = 4;
            }
            if (_nameId == 2) {
                _nameId = 5;
            }
            if (_nameId == 3) {
                _nameId = 6;
            }
        }
        ownerNftIds[msg.sender].push(nftId);
        _safeMint(msg.sender, nftId);
        emit BuyNFT(msg.sender, nftId, _amount);
        ++nftId;
        ++totalNftCount;
        return true;
    }

    /// @notice Listing an NFT board on marketplace
    /// @dev Capped at 200 to stop the array iterations breaking on purchase
    /// @param _listedAmount The listed amount the NFT is selling for
    /// @param _nftId The NFT to be sold
    /// @return bool True if success, false if failed
    function listBoard(uint256 _listedAmount, uint256 _nftId, bytes memory _nodeData, bytes memory _sig) external nonReentrant() returns (bool) {
        require(block.timestamp - lastTimeWasListed[_nftId] >= 48 hours, "Need to wait at least 48 hours before listing");
        require(ownerNftIds[msg.sender].length > 1, "You can't list your last NFT");
        require(ownerboardListingCount[msg.sender] <= 9, "You have too many nfts listed, burn one");
        require (_listedAmount > nftPrice, "Price needs to be more than 50000 tokens");
        require (boardToOwner[_nftId] == msg.sender, "You dont own this nft");
        require(listedBool[_nftId] == false, "NFT is listed, please unlist first");
        require(globalboardListingCount == 0 || isValidNode(nodes[0].prev));
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _nftId + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        boardToOwner[_nftId] = address(this);
        listedBool[_nftId] = true;
        listedAmount[_nftId] = _listedAmount;
        ownerboardListingCount[msg.sender] += 1;
        ownerboardCount[msg.sender] -= 1;
        ownerListedNftIds[msg.sender].push(_nftId);
        lastTimeWasListed[_nftId] = block.timestamp;
        /// @dev node stuff
        Node storage node = nodes[nodes[0].prev];
        nodes.push(Node({
            data: _nodeData,
            prev: nodes[0].prev,
            next: node.next
        }));
        uint newID = nodes.length - 1;
        nodes[node.next].prev = newID;
        node.next = newID;
        nodeListedNftId[_nftId] = newID;
        ++globalboardListingCount;
        /// @dev events
        emit ListNFT(msg.sender, nftId, _listedAmount);
        return true;
    }

    /// @notice Cancel an NFTboard listing on the marketplace
    /// @param _nftId The NFT ID to cancelled
    /// @return bool True if success, false if failed
    function cancelListedBoard(uint256 _nftId, uint _nodeId, bytes memory _sig) external nonReentrant() returns (bool) {
        require(msg.sender == listedBoardToOwner[_nftId], "You don't own this nft");
        require(boardToOwner[_nftId] == address(this), "NFT isn't listed");
        require(listedBool[_nftId] == true, "NFT isn't listed");
        require(ownerboardCount[msg.sender] <= 9, "You have too many nfts in your account, burn one");
        require(isValidNode(_nodeId), "Node ID invalid");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _nftId + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        nodeListedNftId[_nftId] = 0;
        boardToOwner[_nftId] = msg.sender;
        listedBool[_nftId] = false;
        /// @dev Removes item from owners listed array
        for (uint256 x = 0; x < ownerListedNftIds[msg.sender].length; ++x) {
            if (ownerListedNftIds[msg.sender][x] == _nftId) {
                uint256 nftindex = x;
                /// @dev Copies the last place item into the 0 slot
                ownerListedNftIds[msg.sender][nftindex] = ownerListedNftIds[msg.sender][ownerListedNftIds[msg.sender].length-1];
            }
        }
        /// @dev Pop removes last item from the array to keep it clean
        ownerListedNftIds[msg.sender].pop();
        ownerboardListingCount[msg.sender] -= 1;
        ownerboardCount[msg.sender] += 1;
        /// @dev node stuff
        Node storage node = nodes[_nodeId];
        nodes[node.next].prev = node.prev;
        nodes[node.prev].next = node.next;
        delete nodes[_nodeId];
        --globalboardListingCount;
        /// @dev events
        emit CancelNFTListing(msg.sender, nftId);
        return true;
    }

    /// @notice Buying a listed board on marketplace (This is a developer earn mechanic)
    /// @param _from The NFT seller
    /// @param _nftId The NFT ID to purchased
    /// @param _listedAmount The amount the NFT is listed for
    /// @return bool True if success, false if failed
    function buyListedBoard(address _from, uint256 _nftId, uint256 _listedAmount, uint _nodeId, bytes memory _sig) external nonReentrant() returns (bool) {
        require(address(this) == boardToOwner[_nftId], "You don't own this nft");
        require (_listedAmount == listedAmount[_nftId], "You need to pay more");
        require(listedBool[_nftId] == true, "Nft isn't listed");
        require(ownerboardCount[msg.sender] <= 9, "You own too many nfts, burn one");
        require (_token.balanceOf(address(msg.sender)) >= _listedAmount, "Not enough balance to do that");
        require (_nodeId == nodeListedNftId[_nftId], "Node ID invalid");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + _nftId + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        uint _devAmount = _listedAmount * 10/100;
        uint _listedAmount90 = _listedAmount * 90/100;
        _token.gameTokenTransfer(msg.sender, devWallet, _devAmount);
        _token.gameTokenTransfer(msg.sender, _from, _listedAmount90);
        boardToOwner[_nftId] = msg.sender;
        listedBoardToOwner[_nftId] = msg.sender;
        listedBool[_nftId] = false;
        ownerboardListingCount[_from] -= 1;
        ownerboardCount[msg.sender] += 1;
        ownerNftIds[msg.sender].push(_nftId);
        ++nonce[msg.sender];
        /// @dev removes item from the owners listing array
        for (uint256 x = 0; x < ownerListedNftIds[_from].length; ++x) {
            if (ownerListedNftIds[_from][x] == _nftId) {
                uint256 listedNftIndex = x;
                /// @dev Copies the last place item into the 0 slot
                ownerListedNftIds[_from][listedNftIndex] = ownerListedNftIds[_from][ownerListedNftIds[_from].length-1];
            }
        }
        /// @dev Pop removes last item from the array to keep it clean
        ownerListedNftIds[_from].pop();
        /// @dev removes item from the owners board array
        for (uint256 x = 0; x < ownerNftIds[_from].length; ++x) {
            if (ownerNftIds[_from][x] == _nftId) {
                uint256 nftindex = x;
                /// @dev Copies the last place item into the 0 slot
                ownerNftIds[_from][nftindex] = ownerNftIds[_from][ownerNftIds[_from].length-1];
            }
        }
        /// @dev Pop removes last item from the array to keep it clean
        ownerNftIds[_from].pop();
        /// @dev node stuff
        Node storage node = nodes[_nodeId];
        nodes[node.next].prev = node.prev;
        nodes[node.prev].next = node.next;
        delete nodes[_nodeId];
        nodeListedNftId[_nftId] = 0;
        --globalboardListingCount;
        /// @dev events
        emit BuyListedNFT(_from, msg.sender, _nftId, _listedAmount90);
        emit BuyListedNFT(devWallet, msg.sender, _nftId, _devAmount);
        emit Transfer(address(this), msg.sender, _nftId);
        return true;
    }

    /// @notice Decrease an NFTboard's speed (This is a developer earn mechanic)
    /// @param _nftId The NFT ID to be altered
    /// @param _amount The amount of tokens to transfer
    /// @param _sig The signature from the authorization wallet
    /// @return bool true on success false on fail
    function decreaseBoardSpeed(uint256 _nftId, uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        require(_amount == upgradePrice, "Value not equal to amount");
        require (msg.sender == boardToOwner[_nftId], "You don't own this nft");
        require (speed[_nftId] <= 14, "Speed maxed out");
        require(listedBool[_nftId] == false, "NFT is listed, please unlist first");
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        _token.gameTokenTransfer(msg.sender, devWallet, _amount);
        speed[_nftId] += 1;
        emit UpgradeNFT(msg.sender, nftId, _amount);
        return true;
    }

    /// @notice Increase an NFTboard's weapon slots (This is a developer earn mechanic)
    /// @param _nftId The NFT ID to be altered
    /// @param _amount The amount of tokens to transfer
    /// @param _sig The signature from the authorization wallet
    /// @return bool true on success false on fail
    function increaseWeaponSlots(uint256 _nftId, uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        require(_amount == upgradePrice, "Value not equal to amount");
        require (msg.sender == boardToOwner[_nftId], "You don't own this nft");
        require (weaponSlots[_nftId] <= 2, "Weapon slots maxed out");
        require(listedBool[_nftId] == false, "Nft is listed, please unlist first");
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        _token.gameTokenTransfer(msg.sender, devWallet, _amount);
        weaponSlots[_nftId] += 1;
        emit UpgradeNFT(msg.sender, nftId, _amount);
        return true;
    }

    /// @notice Increase an NFTboard's health (This is a developer earn mechanic)
    /// @param _nftId The NFT ID to be altered
    /// @param _amount The amount of tokens to transfer
    /// @param _sig The signature from the authorization wallet
    /// @return bool true on success false on fail
    function increaseHealth(uint256 _nftId, uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        require(_amount == upgradePrice, "Value not equal to amount");
        require (msg.sender == boardToOwner[_nftId], "You don't own this nft");
        require(listedBool[_nftId] == false, "NFT is listed, please unlist first");
        require (health[_nftId] <= 14, "Health maxed out");
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        _token.gameTokenTransfer(msg.sender, devWallet, _amount);
        health[_nftId] += 1;
        emit UpgradeNFT(msg.sender, nftId, _amount);
        return true;
    }

    /// @dev Burn function for NFTboards as the user can only hold 10 NFTboards to stop their array from getting too large
    /// @notice Burn an NFTboard
    /// @param _nftId The NFT ID to burn
    /// @param _sig The signature from the authorization wallet
    /// @return bool Returns true if burn of NFT is successful
    function burnBoard(uint256 _nftId, bytes memory _sig) external nonReentrant() returns (bool) {
        require (boardToOwner[_nftId] == msg.sender, "You don't own this nft");
        require(listedBool[_nftId] == false, "Nft is listed, please unlist first");
        require(ownerNftIds[msg.sender].length > 1, "You can't burn your last NFT");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        boardToOwner[_nftId] = address(0);
        ownerboardCount[address(0)] += 1;
        ownerboardCount[msg.sender]  -= 1;
        for (uint256 x = 0; x < ownerNftIds[msg.sender].length; ++x) {
            if (ownerNftIds[msg.sender][x] == _nftId) {
                uint256 nftindex = x;
                /// @dev Copies the last place item into the 0 slot
                ownerNftIds[msg.sender][nftindex] = ownerNftIds[msg.sender][ownerNftIds[msg.sender].length-1];
            }
        }
        /// @dev Pop removes last item from the array to keep it clean
        ownerNftIds[msg.sender].pop();
        --totalNftCount;
        emit BurnNFT(msg.sender, address(0), _nftId);
        emit Transfer(msg.sender, address(0), _nftId);
        return true;
    }

    /// @dev Dbag dave functions, used as a sink, stops use of Nft boards ingame if amount isn't paid weekly and resets periodically (This is a burn mechanic)
    /// @notice Pay Dbag Dave
    /// @param _amount The amount being paid to Dbag Dave
    /// @param _sig The signature from the authorization wallet
    /// @return bool Returns true if payment is successful
    function payDbagDave(uint256 _amount, bytes memory _sig) external nonReentrant() returns (bool) {
        require (_token.balanceOf(address(msg.sender)) >= _amount, "Not enough balance to do that");
        bytes32 messageHash = getMessageHash(Strings.toString(nonce[msg.sender] + (uint256(uint160(msg.sender))/1e40)));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        require(recover(ethSignedMessageHash, _sig) == authWallet, "Sig not made by auth");
        ++nonce[msg.sender];
        _token.burn(msg.sender, _amount);
        /// @dev checks if the time between Dbagdavetimer time and now is over 7 days
        uint256 nowTime = block.timestamp-dbagDaveTimer[msg.sender];
        if (nowTime > 7 days) {
            dbagDaveTimer[msg.sender] = block.timestamp;
            dbagDavePaidAmount[msg.sender] = _amount;
            emit PayDbagDave(msg.sender, _amount);
            return true;
        } else {
            dbagDavePaidAmount[msg.sender] += _amount;
            emit PayDbagDave(msg.sender, _amount);
            return true;
        }
    }

    /// @notice Check if Dbag Dave has been paid this week, capped at a % of users weekly earn cap
    /// @param _wallet The users wallet address
    /// @param _earnSupplyDaily The users daily earn supply
    /// @return bool True if paid, false if not
    function hasDbagDaveBeenPaid(address _wallet, uint256 _earnSupplyDaily) public view returns (bool) {
        /// @dev checks if the time between Dbagdavetimer time and now is over 7 days
        uint256 nowTime = block.timestamp-dbagDaveTimer[_wallet];
        uint256 davesEarnCap = ((_earnSupplyDaily*7)*dbagDaveWeeklyEarnCapPercentage/100)*1e18;
        /// @dev if time is less than 7 days since Dbagdave was last paid his weekly amount returns true
        if ((dbagDavePaidAmount[_wallet] >= davesEarnCap) && (nowTime <= 7 days)) {
            return true;
        } else {
            return false;
        }
    }

    /// @notice Check if Dbag Dave has been paid this week
    /// @return uint256 Number of days left till Dbagdave breaks boards making them unusable
    function dbagDaveTimeLeft(address _wallet) public view returns (uint256) {
        /// @dev checks if the time between Dbagdavetimer time and now is over 7 days
        uint256 nowTime = block.timestamp-dbagDaveTimer[_wallet];
        if (nowTime < 1 days) {
            return uint256(7);
        } else if (nowTime < 2 days) {
            return uint256(6);
        }
        if (nowTime < 3 days) {
            return uint256(5);
        } else if (nowTime < 4 days) {
            return uint256(4);
        }
        if (nowTime < 5 days) {
            return uint256(3);
        } else if (nowTime < 6 days) {
            return uint256(2);
        }
        if (nowTime < 7 days) {
            return uint256(1);
        }
        else 
        return uint256(0);
    }

    /// @dev Used by owner to change price of Nfts
    /// @param _amount Price amount to change to
    /// @return true if successful
    function changeNftPrice(uint256 _amount) external nonReentrant() onlyOwner() returns (bool) {
        nftPrice = _amount*1e18;
        return true;
    }
    
    /// @dev Used by owner to change price of Nft upgrades
    /// @param _amount Price amount to change to
    /// @return true if successful
    function changeNftUpgradePrice(uint256 _amount) external nonReentrant() onlyOwner() returns (bool) {
        upgradePrice = _amount*1e18;
        return true;
    }
    
    /// @dev Used by owner to change price of DbagDaves weekly amount 
    /// @param _percent Amount to change the percentage to
    /// @return true if successful
    function changeDbagDaveWeeklyEarnCapPercentage(uint256 _percent) external nonReentrant() onlyOwner() returns (bool) {
        dbagDaveWeeklyEarnCapPercentage = _percent;
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

    /// @notice NFT's total supply
    /// @return uint256 NFT's total supply
    function totalSupply() public view returns (uint256) {
        return totalNftCount;
    }

    /// @notice NFT's tokenURI
    /// @return string of nftId token uri
    function tokenURI(uint256 _nftId) public view override returns (string memory) {
        if (nameId[_nftId] == 6)
        {
            return string(bytes.concat(bytes(BASE_URI), bytes(URI6)));
        }
        else if (nameId[_nftId] == 5)
        {
            return string(bytes.concat(bytes(BASE_URI), bytes(URI5)));
        }
        else if (nameId[_nftId] == 4)
        {
            return string(bytes.concat(bytes(BASE_URI), bytes(URI4)));
        }
        else if (nameId[_nftId] == 3)
        {
            return string(bytes.concat(bytes(BASE_URI), bytes(URI3)));
        }
        else if (nameId[_nftId] == 2)
        {
            return string(bytes.concat(bytes(BASE_URI), bytes(URI2)));
        }
        else
        {
            return string(bytes.concat(bytes(BASE_URI), bytes(URI1)));
        }
    }

    /// @dev NFTBoard getter functions, used in gameplay and the marketplace

    /// @notice Gets the NFTboard balance of an address
    /// @return uint256 The total amount of NFTs of an address owned and listed
    function balanceOf(address _wallet) public view override returns (uint256) {
        return ownerboardCount[_wallet] + ownerboardListingCount[_wallet];
    }

    /// @notice Gets an array of NFTboards owned by an address
    /// @return uint256[] The NFTIDs owned by an address
    function getOwnerNftIds(address _wallet) external view returns (uint256[] memory) {
        return ownerNftIds[_wallet];
    }

    /// @notice Gets an array of listed NFTboards owned by an address
    /// @return uint256[] Listed NFT IDs from an address
    function getOwnerListedNftIds(address _wallet) external view returns (uint256[] memory) {
        return ownerListedNftIds[_wallet];
    }

    /// @dev Gets NFT board stats, used for the users nfts and listed nfts in their inventory as that array is capped to 10 per user
    /// @param _nftId ID of the Nft board
    /// @return array of user Nft board stats
    function nftStats(uint256 _nftId) external view returns (bool, uint256, uint256, uint256, uint256, uint256, uint256) {
        return (
            listedBool[_nftId],
            nameId[_nftId],
            speed[_nftId],
            weaponSlots[_nftId],
            rarity[_nftId],
            health[_nftId],
            listedAmount[_nftId]
        );
    }

    /// @dev NFT Contracts Caps
    /// @return array of nft contract caps
    function nftCaps() external view returns (uint256, uint256, uint256) {
        return (
            nftPrice,
            upgradePrice,
            dbagDaveWeeklyEarnCapPercentage
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
        assembly {
            r := mload(add(_sig, 32))
            s := mload(add(_sig, 64))
            v := byte(0, mload(add(_sig, 96)))
        }
    }
}