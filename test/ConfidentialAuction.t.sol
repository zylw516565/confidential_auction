// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import "../src/ConfidentialAuction.sol";
import "./utils/TestActors.sol";
import "./utils/TestERC721.sol";

contract ConfidentialAuctionTest is IConfidentialAuctionErrors, TestActors {
  ConfidentialAuction auction;
  TestERC721 erc721;

  uint64  constant ONE_ETH  = uint64(1 ether / 1000 gwei);
  uint256 constant TOKEN_ID = 1;

  function setUp() public override {
    super.setUp();
    auction = new ConfidentialAuction();
    erc721  = new TestERC721();
    erc721.mint(alice, TOKEN_ID);
    hoax(alice);
    erc721.setApprovalForAll(address(auction), true);

    console2.log("setUp !!!");
  }

  function testCreateAuction() external {
    ConfidentialAuction.Auction memory expectedAuction =
      ConfidentialAuction.Auction({
        seller: alice,
        endOfBiddingPeriod: uint32(block.timestamp + 1 hours),
        started: true,
        count: 1,
        topBid: ONE_ETH,
        secondTopBid: ONE_ETH,
        reservePrice: ONE_ETH,
        topBidder: address(0)
      });

    ConfidentialAuction.Auction memory actualAuction = 
      createAuction(TOKEN_ID);

    assertAuctionsEqual(actualAuction, expectedAuction);
  }

  function testCannotCreateAuctionForItemThatYouDoNotOwn() external {
      vm.expectRevert("ERC721NonexistentToken(4)");
      createAuction(4);
  }

  function test_bid() external {
    
  }




//-------------------------------------------------------------------

  function createAuction(uint256 tokenId) 
      private 
      returns (ConfidentialAuction.Auction memory a)
  {
      hoax(alice);
      auction.createAuction(
          address(erc721),
          tokenId,
          1 hours,
          ONE_ETH
      );
      return auction.getAuction(address(erc721), tokenId);
  }

  function assertAuctionsEqual(
      ConfidentialAuction.Auction memory actualAuction,
      ConfidentialAuction.Auction memory expectedAuction
  ) private {
      assertEq(actualAuction.seller, expectedAuction.seller, "seller");
      assertEq(actualAuction.endOfBiddingPeriod, expectedAuction.endOfBiddingPeriod, "endOfBiddingPeriod");
      assertEq(actualAuction.started, expectedAuction.started, "started");
      assertEq(actualAuction.count, expectedAuction.count, "count");
      assertEq(actualAuction.topBid, expectedAuction.topBid, "topBid");
      assertEq(actualAuction.secondTopBid, expectedAuction.secondTopBid, "secondTopBid");
      assertEq(actualAuction.reservePrice, expectedAuction.reservePrice, "reservePrice");
      assertEq(actualAuction.topBidder, expectedAuction.topBidder, "topBidder");
  }
}