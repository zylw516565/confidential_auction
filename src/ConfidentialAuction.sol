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


  function revealBid(
      address tokenContract,
      uint256 tokenId,
      uint48 bidValue,
      bytes32 salt,
      CollateralizationProof calldata proof
  )
      external
      nonReentrant
  {
    Auction storage auction = auctions_[tokenContract][tokenId];

    // The bidding for the auction hasn't started yet or the time for disclosing the bid has passed
    if(
      block.timestamp <= auction.endOfBiddingPeriod ||
      block.timestamp >  auction.endOfRevealPeriod
    ) {
      revert NotInRevealPeriodError();
    }

    uint32 auctionIndex = auction.count;
    address vault = getVaultAddress(
        tokenContract, 
        tokenId, 
        auctionIndex, 
        msg.sender, 
        bidValue, 
        salt
    );

    if(revealedVaults_[vault]) {
      revert BidAlreadyRevealedError(vault);
    }
    revealedVaults_[vault] = true;

    uint256 bidValueWei = bidValue * BASE_BID_UNIT;
    bool isCollateralized = true;

    // If this is the first bid revealed, record the block hash of the 
    // previous block. All other bids must have been collateralized by 
    // that block. 
    if (auction.collateralizationDeadlineBlockHash == bytes32(0)) {
      if (vault.balance < bidValueWei) {
          // Deploy vault to return ETH to bidder
          new ConfidentialVault{salt: salt}(
              tokenContract, 
              tokenId, 
              auctionIndex, 
              msg.sender,
              bidValue
          );
          isCollateralized = false;
      } else {
          auction.collateralizationDeadlineBlockHash = blockhash(block.number - 1);
          emit CollateralizationDeadlineSet(
              tokenContract, 
              tokenId, 
              auctionIndex,
              block.number - 1
          );
      }
    } else {
      // All other bidders must prove that their balance was 
      // sufficiently collateralized by the deadline block.
      uint256 vaultBalance = _getProvenAccountBalance(
          proof.accountMerkleProof,
          proof.blockHeaderRLP,
          auction.collateralizationDeadlineBlockHash,
          vault
      );
      if (vaultBalance < bidValueWei) {
          // Deploy vault to return ETH to bidder
          new ConfidentialVault{salt: salt}(
              tokenContract, 
              tokenId, 
              auctionIndex, 
              msg.sender,
              bidValue
          );
          isCollateralized = false;
      }
    }

    if (isCollateralized) {
        // Update record of (second-)highest bid as necessary
        uint64 currentTopBid = auction.topBid;
        if (bidValue > currentTopBid) {
            auction.topBid = bidValue;
            auction.secondTopBid = currentTopBid;
            auction.topBidVault = vault;
        } else {
            if (bidValue > auction.secondTopBid) {
                auction.secondTopBid = bidValue;
            }
            // Deploy vault to return ETH to bidder
            new ConfidentialVault{salt: salt}(
                tokenContract, 
                tokenId, 
                auctionIndex, 
                msg.sender,
                bidValue
            );
        }

        emit BidRevealed(
            tokenContract,
            tokenId,
            vault,
            msg.sender,
            salt,
            bidValueWei
        );
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
      returns (uint256 bid)
  {
      return auctions_[tokenContract][tokenId].secondTopBid * BASE_BID_UNIT;
  }

  // Returns vault address associated with the highest bid for the most 
  // recent auction of the given asset.
  function getHighestBidVault(
      address tokenContract,
      uint256 tokenId
  )
      external
      view
      returns (address vault)
  {
      return auctions_[tokenContract][tokenId].topBidVault;
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