// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IConfidentialAuctionErrors.sol";

contract ConfidentialAuction is IConfidentialAuctionErrors, ReentrancyGuard{
  //The base unit for bids.
  uint256 public constant BASE_BID_UNIT = 1000 gwei;

  //Representation of an auction in storage.
  struct Auction {
    address seller;
    uint32  endOfBiddingPeriod;
    uint32  endOfRevealPeriod;
    uint32  count;
    //-------------------
    uint64  topBid;
    uint64  secondTopBid;
    address topBidVault;
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

  // Emitted when the first bid is revealed for an auction.
  event CollateralizationDeadlineSet(
      address tokenContract,
      uint256 tokenId,
      uint32 index,
      uint256 deadlineBlockNumber
  );

  // A mapping storing auction parameters and state, indexed by
  // the ERC721 contract address and token ID of the asset being
  // auctioned.
  mapping(address => mapping(uint256 => Auction)) public auctions_;

  // A mapping storing whether or not the bid for a `ConfidentialVault` was revealed. 
  mapping(address => bool) public revealedVaults_;

  function createAuction(
    address tokenContract,
    uint256 tokenId,
    uint32  bidPeriod,
    uint32  revealPeriod,
    uint64 reservePrice
  ) 
    external nonReentrant
  {
    Auction storage auction = auctions_[tokenContract][tokenId];

    if (bidPeriod < 1 hours) {
      revert BidPeriodTooShortError(bidPeriod);
    }

    if (revealPeriod < 1 hours) {
      revert RevealPeriodTooShortError(revealPeriod);
    }

    auction.seller = msg.sender;
    auction.endOfBiddingPeriod = uint32(block.timestamp) + bidPeriod;
    auction.endOfRevealPeriod  = uint32(block.timestamp) + bidPeriod + revealPeriod;

    // Increment auction count
    auction.count++;

    // Both top and second-top bid are set to the reserve price.
    // Any winning bid must be at least this price, and the winner will 
    // pay at least this price.
    auction.topBid = reservePrice;
    auction.secondTopBid = reservePrice;
    // Reset
    auction.topBidVault = address(0);
    auction.collateralizationDeadlineBlockHash = bytes32(0);

    // The seller transfers the NFT assets to the current contract
    ERC721(tokenContract).transferFrom(msg.sender, address(this), tokenId);

    emit AuctionCreated(
      tokenContract,
      tokenId,
      msg.sender,
      bidPeriod,
      revealPeriod,
      reservePrice
    );
  }


}