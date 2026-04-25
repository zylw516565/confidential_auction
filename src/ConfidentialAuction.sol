// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IConfidentialAuctionErrors.sol";
import "@iexec-nox/nox-protocol-contracts/contracts/sdk/Nox.sol";

contract ConfidentialAuction is IConfidentialAuctionErrors, ReentrancyGuard{

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
  }

  struct BidInfo {
    uint256 bidValue;
    address tokenContract;
    uint256 tokenId;
  }

  // Emitted when an auction is created.
  event AuctionCreated(
      address tokenContract,
      uint256 tokenId,
      address seller,
      uint32 bidPeriod,
      uint256 reservePrice
  );

  event Bidded(
      address tokenContract,
      uint256 tokenId
  );

  // A mapping storing auction parameters and state, indexed by
  // the ERC721 contract address and token ID of the asset being
  // auctioned.
  mapping(address => mapping(uint256 => Auction)) public auctions_;

  //The bids of all participants for a certain NTF
  mapping(address => mapping(uint256 => mapping(address => BidInfo))) public biddings_;

  function createAuction(
    address tokenContract,
    uint256 tokenId,
    uint32  bidPeriod,
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

    // The seller transfers the NFT assets to the current contract
    ERC721(tokenContract).transferFrom(msg.sender, address(this), tokenId);

    auction.started = true;
    emit AuctionCreated(
      tokenContract,
      tokenId,
      msg.sender,
      bidPeriod,
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
    if(amount <= 0 ||
       amount <= auction.reservePrice
    ) {
      revert InvalidBidError(amount);
    }

    if (biddings_[tokenContract][tokenId][msg.sender].bidValue > 0) {
      revert AlreadyBidError();
    }

    biddings_[tokenContract][tokenId][msg.sender].bidValue += amount;
    biddings_[tokenContract][tokenId][msg.sender].tokenContract = tokenContract;
    biddings_[tokenContract][tokenId][msg.sender].tokenId = tokenId;

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

  // receive() external payable {}
  // fallback() external payable {}

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
    if (false == auction.started) {
      revert NoNeedEndAuction();
    }

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
      ERC721(tokenContract).safeTransferFrom(address(this), auction.topBidder, tokenId);

      // Transfer ETH to seller
      require(address(this).balance >= auction.secondTopBid);
      (bool success, ) = auction.seller.call{value: auction.secondTopBid}("");
      require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');

      // returning any excess to bidder
      BidInfo memory bidinfo = biddings_[tokenContract][tokenId][auction.topBidder];
      uint256 excessETH = bidinfo.bidValue - auction.secondTopBid;
      require(address(this).balance >= excessETH);
      (success, ) =  auction.topBidder.call{value: excessETH}("");
      require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');

      // reset top bidder's bidValue
      biddings_[tokenContract][tokenId][auction.topBidder].bidValue = 0;
    }

    auction.started = false;
  }

  /// @notice Withdraws collateral from auction contract once an auction is over.
  /// @param tokenContract The address of the ERC721 contract for the asset
  ///        that was auctioned.
  /// @param tokenId The ERC721 token ID of the asset that was auctioned.
  function withdrawCollateral(
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

    BidInfo memory bidinfo = biddings_[tokenContract][tokenId][msg.sender];
    uint256 withdrawAmount = bidinfo.bidValue;
    if (
      withdrawAmount <= 0 ||
      tokenContract != bidinfo.tokenContract ||
      tokenId       != bidinfo.tokenId
    ) {
      revert NoRefundBalanceError();
    }

    require(address(this).balance >= withdrawAmount, NoRefundBalanceError());

    // reset bidder's bidValue
    biddings_[tokenContract][tokenId][msg.sender].bidValue = 0;

    (bool success, ) = msg.sender.call{value: withdrawAmount}("");
    require(success, 'TransferHelper::call: ETH transfer failed');
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
      return auctions_[tokenContract][tokenId].secondTopBid;
  }

  // Gets the parameters and state of an auction in storage.
  function getAuction(address tokenContract, uint256 tokenId)
      external
      view
      returns (Auction memory auction)
  {
      return auctions_[tokenContract][tokenId];
  }

  function getBidInfo(address tokenContract, uint256 tokenId, address bidder) external view returns (BidInfo memory info) {
    return biddings_[tokenContract][tokenId][bidder];
  }

}