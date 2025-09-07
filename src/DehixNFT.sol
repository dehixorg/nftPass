// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "@chainlink/contracts/src/interfaces/feeds/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DehixNFT is ERC721Enumerable, Ownable {
    enum Tier {
        Silver,
        Gold
    }

    uint256 public constant SILVER_PRICE = 99;
    uint256 public constant GOLD_PRICE = 299;

    uint256 public constant ACCESS_DURATION = 365 days * 10;

    uint256 public capSilver;
    uint256 public capGold;
    uint256 public mintedSilver;
    uint256 public mintedGold;

    uint256 private _nextCount = 1;

    AggregatorV3Interface internal priceFeed;

    string public silverMetadataURI =
        "https://yellow-tricky-moth-307.mypinata.cloud/ipfs/bafybeiedcs32w623wvgbn2rcgwad2c3pcd4pvihtlowsswlw7qzfwhkswm/Silver.json";
    string public goldMetadataURI =
        "https://yellow-tricky-moth-307.mypinata.cloud/ipfs/bafybeiedcs32w623wvgbn2rcgwad2c3pcd4pvihtlowsswlw7qzfwhkswm/Gold.json";

    mapping(uint256 => Tier) public tierOf;
    mapping(uint256 => uint256) public expiryOf;

    event SilverPurchased(address indexed buyer, uint256 indexed id);
    event GoldPurchased(address indexed buyer, uint256 indexed id);
    event FundsWithdrawn(uint256 amount);

    constructor(
        uint256 _capSilver,
        uint256 _capGold,
        address _priceFeedAddress
    ) ERC721("Dehix NFT", "DNFT") Ownable() {
        capSilver = _capSilver;
        capGold = _capGold;
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    function buySilver() external payable {
        require(msg.value >= usdToEth(SILVER_PRICE), "Wrong ETH amount");
        require(mintedSilver < capSilver, "Silver sold out");

        uint256 tokenId = generateNFTid();
        _safeMint(msg.sender, tokenId);

        tierOf[tokenId] = Tier.Silver;
        expiryOf[tokenId] = block.timestamp + ACCESS_DURATION;

        mintedSilver++;

        emit SilverPurchased(msg.sender, tokenId);
    }

    function buyGold() external payable {
        require(msg.value >= usdToEth(GOLD_PRICE), "Wrong ETH amount");
        require(mintedGold < capGold, "Gold sold out");

        uint256 tokenId = generateNFTid();
        _safeMint(msg.sender, tokenId);

        tierOf[tokenId] = Tier.Gold;
        expiryOf[tokenId] = block.timestamp + ACCESS_DURATION;

        mintedGold++;

        emit GoldPurchased(msg.sender, tokenId);
    }

    function increaseSilverCap(uint _increaseBy) external onlyOwner {
        capSilver += _increaseBy;
    }

    function increaseGoldCap(uint _increaseBy) external onlyOwner {
        capGold += _increaseBy;
    }

    function withdraw() external onlyOwner {
        uint amount = address(this).balance;
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Failed to withdraw");
        emit FundsWithdrawn(amount);
    }

    function generateNFTid() internal returns (uint256) {
        uint id = uint(
            keccak256(abi.encodePacked(block.timestamp, msg.sender, _nextCount))
        ) % 1_000_000;
        _nextCount++;
        return id;
    }

    // USD to ETH conversion functions
    function getLatestETHPrice() public view returns (uint256) {
        (, int price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price data");
        return uint256(price) * 1e10; // Adjust precision to 18 decimal places. Chainlink price feeds return 8 decimal places
    }

    function usdToEth(uint _amountUSD) public view returns (uint) {
        uint256 adjustedUsd = _amountUSD * (1e18); // adjusting to 18 decimal places
        uint256 ethPrice = getLatestETHPrice();
        return (adjustedUsd * 1e18) / ethPrice; // multiplying again with 1e18 to get eth amount in wei
    }

    function hasActiveAccess(address user) external view returns (bool) {
        uint256 balance = balanceOf(user);

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(user, i);
            if (expiryOf[tokenId] > block.timestamp) {
                return true;
            }
        }
        return false;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(
            _ownerOf(tokenId) != address(0),
            "URI query for nonexistent token"
        );

        if (tierOf[tokenId] == Tier.Silver) {
            return silverMetadataURI;
        } else {
            return goldMetadataURI;
        }
    }

    function getSilverPriceInETH() public view returns (uint256) {
        uint price = usdToEth(SILVER_PRICE);
        return (price);
    }

    function getGoldPriceInETH() public view returns (uint256) {
        uint price = usdToEth(GOLD_PRICE);
        return (price);
    }
}
