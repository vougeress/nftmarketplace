// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract SubscriptionModel {
    mapping(uint256 => uint64) internal _expirations;

    /// @notice Emitted when a subscription expiration changes
    /// @dev When a subscription is canceled, the expiration value should also be 0.
    event SubscriptionUpdate(uint256 indexed tokenId, uint64 expiration);

    /// @notice Renews the subscription to an NFT
    /// Throws if `tokenId` is not a valid NFT
    /// @param _tokenId The NFT to renew the subscription for
    /// @param duration The number of seconds to extend a subscription for
    function renewSubscription(
        uint256 _tokenId,
        uint64 duration
    ) external payable {
        uint64 currentExpiration = _expirations[_tokenId];
        uint64 newExpiration;
        if (currentExpiration == 0) {
            // block.timestamp -> Current block timestamp as seconds since unix epoch
            newExpiration = uint64(block.timestamp) + duration;
        } else {
            require(isRenewable(_tokenId), "Subscription Not Renewable");
            newExpiration = currentExpiration + duration;
        }
        _expirations[_tokenId] = newExpiration;
        emit SubscriptionUpdate(_tokenId, newExpiration);
    }

    /// @notice Cancels the subscription of an NFT
    /// @dev Throws if `tokenId` is not a valid NFT
    /// @param _tokenId The NFT to cancel the subscription for
    function cancelSubscription(uint256 _tokenId) external payable {
        delete _expirations[_tokenId];
        emit SubscriptionUpdate(_tokenId, 0);
    }

    /// @notice Gets the expiration date of a subscription
    /// @dev Throws if `tokenId` is not a valid NFT
    /// @param _tokenId The NFT to get the expiration date of
    /// @return The expiration date of the subscription
    function expiresAt(uint256 _tokenId) external view returns (uint64) {
        return _expirations[_tokenId];
    }

    /// @notice Determines whether a subscription can be renewed
    /// @dev Throws if `tokenId` is not a valid NFT
    /// @param tokenId The NFT to get the expiration date of
    /// @return The renewability of the subscription - true or false
    function isRenewable(uint256 tokenId) public pure returns (bool) {
        return true;
    }
}

contract NftMarketplace is ERC721URIStorage {
    uint256 private _tokenIds;
    uint256 private _nftAvailableForSale;
    uint256 private _userIds;

    constructor() ERC721("NFT Marketplace Subscription", "NFT"){}

    struct NftStruct {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        address[] subscribers;
        uint256 likes;
        string title;
        string description;
        string tokenUri;
    }

    struct ProfileStruct {
        address self;
        address[] followers;
        address[] following;
    }

    mapping(uint256 => NftStruct) private nfts;
    mapping(uint256 => ProfileStruct) private profiles;

    event NftStructCreated(
        uint256 tokenId,
        address payable seller,
        address payable owner,
        uint256 price,
        address[] subscribers,
        uint256 likes,
        string title,
        string description
    );

    function setNft(uint256 _tokenId, string memory _title, string memory _description, string memory _tokenUri) public {
        address[] memory initialSubscribers = new address[](1);
        initialSubscribers[0] = msg.sender;

        nfts[_tokenId] = NftStruct({
            tokenId: _tokenId,
            seller: payable(msg.sender),
            owner: payable(msg.sender),
            price: 0,
            subscribers: initialSubscribers,
            likes: 1,
            title: _title,
            description: _description,
            tokenUri: _tokenUri
        });

        emit NftStructCreated(_tokenId, payable(msg.sender), payable(msg.sender), 0, nfts[_tokenId].subscribers, nfts[_tokenId].likes, _title, _description);
    }

    function createNft(string memory _tokenUri, string memory _title, string memory _description) public returns (uint256) {
        _tokenIds++;
        uint256 newTokenId = _tokenIds;
        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, _tokenUri);
        setNft(newTokenId, _title, _description, _tokenUri);
        return newTokenId;
    }

    function sellSubscription(uint256 _tokenId, uint256 _price) public returns (uint256) {
        require(ownerOf(_tokenId) == msg.sender, "You are not the owner of this NFT");
        _transfer(msg.sender, address(this), _tokenId);
        nfts[_tokenId].price = _price;
        nfts[_tokenId].owner = payable(address(this));
        _nftAvailableForSale++;
        return _nftAvailableForSale;
    }

    function buySubscription(uint256 _tokenId) public payable returns (bool) {
        uint256 price = nfts[_tokenId].price;
        require(msg.value == price, "The price is not correct");
        payable(nfts[_tokenId].seller).transfer(msg.value);
        nfts[_tokenId].subscribers.push(msg.sender);
        return true;
    }

    function getSubscriptions() public view returns (NftStruct[] memory) {
        uint256 nftCount = _tokenIds;
        uint256 currentIndex = 0;
        NftStruct[] memory nftSubs = new NftStruct[](_nftAvailableForSale);
        for (uint256 i = 1; i <= nftCount; i++) {
            if (nfts[i].owner == address(this)) {
                nftSubs[currentIndex] = nfts[i];
                currentIndex++;
            }
        }
        return nftSubs;
    }

    function getCollectables() public view returns (NftStruct[] memory) {
        uint256 nftCount = _tokenIds;
        uint256 currentIndex = 0;
        NftStruct[] memory nftSubs = new NftStruct[](nftCount);
        for (uint256 i = 1; i <= nftCount; i++) {
            uint256 subscribers = nfts[i].subscribers.length;
            for (uint256 j = 0; j < subscribers; j++) {
                if (nfts[i].subscribers[j] == msg.sender) {
                    nftSubs[currentIndex] = nfts[i];
                    currentIndex++;
                }
            }
        }
        return nftSubs;
    }

    function getCreatedNfts() public view returns (NftStruct[] memory) {
        uint256 nftCount = _tokenIds;
        uint256 currentIndex = 0;
        NftStruct[] memory nftSubs = new NftStruct[](nftCount);
        for (uint256 i = 1; i <= nftCount; i++) {
            if (nfts[i].owner == msg.sender) {
                nftSubs[currentIndex] = nfts[i];
                currentIndex++;
            }
        }
        return nftSubs;
    }

    function getIndividualNtf(uint256 _tokenId) public view returns (NftStruct memory) {
        return nfts[_tokenId];
    }

    function addProfile() public returns (uint256 userId, uint256 balance) {
        _userIds++;
        uint256 newUserId = _userIds;
        profiles[newUserId].self = msg.sender;
        userId = newUserId;
        balance = msg.sender.balance;
    }

    function followProfile(address _account) public {
        uint256 totalCount = _userIds;
        for (uint256 i = 1; i <= totalCount; i++) {
            if (profiles[i].self == msg.sender) {
                profiles[i].following.push(_account);
            }
            if (profiles[i].self == _account) {
                profiles[i].followers.push(msg.sender);
            }
        }
    }

    function unfollowProfile(address _account) public {
        uint256 totalCount = _userIds;
        for (uint256 i = 1; i <= totalCount; i++) {
            if (profiles[i].self == msg.sender) {
                removeAddress(profiles[i].following, _account);
            }
            if (profiles[i].self == _account) {
                removeAddress(profiles[i].followers, msg.sender);
            }
        }
    }

    function removeAddress(address[] storage array, address _account) internal {
        uint256 length = array.length;
        for (uint256 i = 0; i < length; i++) {
            if (array[i] == _account) {
                array[i] = array[length - 1];
                array.pop();
                break;
            }
        }
    }

    function like(uint256 _tokenId) public {
        nfts[_tokenId].likes += 1;
    }

    function dislike(uint256 _tokenId) public {
        nfts[_tokenId].likes -= 1;
    }
}
