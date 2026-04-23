// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IConfidentialAuctionErrors.sol";
import "./ConfidentialVault.sol";
import "./LibBalanceProof.sol";

contract ConfidentialAuction is IConfidentialAuctionErrors, ReentrancyGuard{
  //The base unit for bids.
  uint256 public constant BASE_BID_UNIT = 1000 gwei;

  //Representation of an auction in storage.
  struct Auction {
    address seller;
    uint32  endOfBiddingPeriod;
    bool    started;
    uint32  count;
    //-------------------
    uint256  topBid;
    uint256  secondTopBid;
    uint256  reservePrice;
    address  topBidder;
    //-------------------
    bytes32 collateralizationDeadlineBlockHash;
  }

  //A Merkle proof and block header
  struct CollateralizationProof {
      bytes[] accountMerkleProof;
      bytes blockHeaderRLP;
  }

  // Emitted when an auction is created.
  event AuctionCreated(
      address tokenContract,
      uint256 tokenId,
      address seller,
      uint32 bidPeriod,
      uint32 revealPeriod,
      uint256 reservePrice
  );

  // Emitted when a bidding is revealed.
  event BidRevealed(
      address tokenContract,
      uint256 tokenId,
      address bidVault,
      address bidder,
      bytes32 salt,
      uint256 bidValue
  );

  event Bidded(
      address tokenContract,
      uint256 tokenId
  );

  // Emitted when the first bid is revealed for an auction.
  event CollateralizationDeadlineSet(
      address tokenContract,
      uint256 tokenId,
      uint32 index,
      uint256 deadlineBlockNumber
  );

  struct BidInfo {
    uint256 bidValue;
    address tokenContract;
    uint256 tokenId;
  }

  // A mapping storing auction parameters and state, indexed by
  // the ERC721 contract address and token ID of the asset being
  // auctioned.
  mapping(address => mapping(uint256 => Auction)) public auctions_;

  //The bids of all participants for a certain NTF
  mapping(address => BidInfo) biddings_;

  function createAuction(
    address tokenContract,
    uint256 tokenId,
    uint32  bidPeriod,
    uint32  revealPeriod,
    uint64  reservePrice
  )
    external nonReentrant
  {
    if(tokenContract == address(0)) {
      revert InvalidTokenContractError();
    }

    Auction storage auction = auctions_[tokenContract][tokenId];

    if (bidPeriod < 1 hours) {
      revert BidPeriodTooShortError(bidPeriod);
    }

    if (revealPeriod < 1 hours) {
      revert RevealPeriodTooShortError(revealPeriod);
    }

    auction.seller = msg.sender;
    auction.endOfBiddingPeriod = uint32(block.timestamp) + bidPeriod;

    // Increment auction count
    auction.count++;

    // Both top and second-top bid are set to the reserve price.
    // Any winning bid must be at least this price, and the winner will 
    // pay at least this price.
    auction.topBid = reservePrice;
    auction.secondTopBid = reservePrice;
    auction.reservePrice = reservePrice;
    // Reset
    auction.topBidder = address(0);
    auction.collateralizationDeadlineBlockHash = bytes32(0);

    // The seller transfers the NFT assets to the current contract
    ERC721(tokenContract).transferFrom(msg.sender, address(this), tokenId);

    auction.started = true;
    emit AuctionCreated(
      tokenContract,
      tokenId,
      msg.sender,
      bidPeriod,
      revealPeriod,
      reservePrice
    );
  }

  /// @param tokenContract The address of the ERC721 contract for the asset
  ///        being auctioned.
  /// @param tokenId The ERC721 token ID of the asset being auctioned.
  function bid(
    address tokenContract,
    uint256 tokenId
  )
    external payable nonReentrant
  {
    if(tokenContract == address(0)) {
      revert InvalidTokenContractError();
    }

    Auction storage auction = auctions_[tokenContract][tokenId];

    if (
      block.timestamp > auction.endOfBiddingPeriod ||
      !auction.started
    ) {
      revert NotInBidPeriodError();
    }

    uint256 amount = msg.value;
    if(amount <= 0) {
      revert InvalidBidError(amount);
    }

    biddings_[msg.sender].bidValue = amount;
    biddings_[msg.sender].tokenContract = tokenContract;
    biddings_[msg.sender].tokenId = tokenId;

    uint256 currentTopBid = auction.topBid;
    if(amount > auction.topBid) {
      auction.topBid       = amount;
      auction.topBidder    = msg.sender;
      auction.secondTopBid = currentTopBid;
    } else {
      if (amount > auction.secondTopBid) {
        auction.secondTopBid = amount;
      }
    }

    emit Bidded(
      tokenContract,
      tokenId
    );
  }

  fallback() external payable {}

  /// @notice Ends an active auction. Can only end an auction if the bid phase is over.
  /// @param tokenContract The address of the ERC721 contract for the asset auctioned.
  /// @param tokenId The ERC721 token ID of the asset auctioned.
  function endAuction(
      address tokenContract,
      uint256 tokenId
  )
    external
    nonReentrant
  {
    if(tokenContract == address(0)) {
      revert InvalidTokenContractError();
    }

    Auction storage auction = auctions_[tokenContract][tokenId];

    if (block.timestamp <= auction.endOfBiddingPeriod) {
      revert BidPeriodOngoingError(block.timestamp, auction.endOfBiddingPeriod);
    }

    // No one made a bid.
    if(
      auction.topBid <= auction.reservePrice ||
      address(0) == auction.topBidder
    ) {
      // No winner, return asset to seller.
      ERC721(tokenContract).safeTransferFrom(address(this), auction.seller, tokenId);
    } else {
      // Transfer auctioned asset to top bidder
      ERC721(tokenContract).safeTransferFrom(address(this), auction.topBidder , tokenId);

      // Transfer ETH to seller
      require(address(this).balance >= auction.secondTopBid);
      (bool success, ) = auction.seller.call{value: auction.secondTopBid}("");
      require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');

      // returning any excess to bidder
      uint256 excessETH = biddings_[auction.topBidder].bidValue - auction.secondTopBid;
      require(address(this).balance >= excessETH);
      (success, ) =  auction.topBidder.call{value: excessETH}("");
      require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }
  }

  // Returns the seller for the most recent auction of the given asset.
  function getSeller(
      address tokenContract,
      uint256 tokenId
  )
    external view
    returns (address seller)
  {
    return auctions_[tokenContract][tokenId].seller;
  }

  // Returns the second highest bid (in wei) for the most recent auction of 
  function getSecondHighestBid(
      address tokenContract,
      uint256 tokenId
  )
    external
    view
    returns (uint256 bidValue)
  {
      return auctions_[tokenContract][tokenId].secondTopBid * BASE_BID_UNIT;
  }

  // Gets the parameters and state of an auction in storage.
  function getAuction(address tokenContract, uint256 tokenId)
      external
      view
      returns (Auction memory auction)
  {
      return auctions_[tokenContract][tokenId];
  }

  // Computes the `CREATE2` address of the `ConfidentialVault` with the given 
  // parameters. Note that the vault contract may not be deployed yet.
  function getVaultAddress(
      address tokenContract,
      uint256 tokenId,
      uint32 auctionIndex,
      address bidder,
      uint48 bidValue,
      bytes32 salt
  )
      public
      view
      returns (address vault)
  {
      // Compute `CREATE2` address of vault
      return address(uint160(uint256(keccak256(abi.encodePacked(
          bytes1(0xff),
          address(this),
          salt,
          keccak256(abi.encodePacked(
              type(ConfidentialVault).creationCode,
              abi.encode(
                  tokenContract, 
                  tokenId, 
                  auctionIndex, 
                  bidder, 
                  bidValue
              )
          ))
      )))));
  }

  // Gets the balance of the given account at a past block by 
  // traversing the given Merkle proof for the state trie. 
  function _getProvenAccountBalance(
      bytes[] memory proof,
      bytes memory blockHeaderRLP,
      bytes32 blockHash,
      address account
  )
      internal
      virtual
      view
      returns (uint256 accountBalance)
  {
      return LibBalanceProof.getProvenAccountBalance(
          proof,
          blockHeaderRLP,
          blockHash,
          account
      );
  }
}