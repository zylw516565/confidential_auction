// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import "../src/ConfidentialAuction.sol";
import "./utils/TestActors.sol";
import "./utils/TestERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ConfidentialAuctionTest is IConfidentialAuctionErrors, TestActors {
  using Strings for *;

  ConfidentialAuction auction;
  TestERC721 erc721;

  uint64  constant ONE_ETH  = uint64(1 ether / 1000 gwei);
  uint64  constant TWO_ETH  = uint64(2 ether / 1000 gwei);
  uint256 constant TOKEN_ID = 1;

  uint256 constant PRANK_GIVE = uint256(10 ether / 1000 gwei);

  function setUp() public override {
    super.setUp();
    auction = new ConfidentialAuction();
    erc721  = new TestERC721();
    erc721.mint(alice, TOKEN_ID);
    hoax(alice, PRANK_GIVE);
    erc721.setApprovalForAll(address(auction), true);

    console2.log("setUp !!!");
    console2.log("ONE_ETH:%d",
                  ONE_ETH);
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
    ConfidentialAuction.BidInfo memory expectedInfo =
      ConfidentialAuction.BidInfo({
        bidValue: TWO_ETH,
        tokenContract: address(erc721),
        tokenId: TOKEN_ID
      });

    createAuction(TOKEN_ID);
    ConfidentialAuction.BidInfo memory actualInfo = doBid(TOKEN_ID, TWO_ETH);
    assertBidEqual(actualInfo, expectedInfo);
  }

  // function test_bidBalanceChange() external {
  //   uint256 before_balance = address(this).balance;
  //   console2.logUint(before_balance);

  //   createAuction(TOKEN_ID);
  //   ConfidentialAuction.BidInfo memory actualInfo = doBid(TOKEN_ID, TWO_ETH);
  //   uint256 after_balance = address(this).balance;
  //   console2.logUint(after_balance);

  //   assertEq(before_balance - after_balance, TWO_ETH);
  // }

  function testCannotBidBeforeCreateAuction() external {
    vm.expectRevert(NotInBidPeriodError.selector);
    doBid(TOKEN_ID, TWO_ETH);
    createAuction(TOKEN_ID);
  }

  function testCannotBidAfterBidPeriod() external {
    createAuction(TOKEN_ID);
    skip(2 hours);
    vm.expectRevert(NotInBidPeriodError.selector);
    doBid(TOKEN_ID, TWO_ETH);
  }

  function testEndAuction() external {
    ConfidentialAuction.Auction memory beforeAuction = createAuction(TOKEN_ID);
    bool statusBeforeEnd = beforeAuction.started;

    skip(2 hours);
    auction.endAuction(address(erc721), TOKEN_ID);
    ConfidentialAuction.Auction memory afterAuction = auction.getAuction(address(erc721), TOKEN_ID);

    bool statusAfterEnd = afterAuction.started;
    assertEq(!statusBeforeEnd, statusAfterEnd, "statusAfterEnd");
    assertEq(false, statusAfterEnd, "statusAfterEnd");
  }

  function testCannotEndAuctionBeforeCreateAuction() external {
    vm.expectRevert(NoNeedEndAuction.selector);

    auction.endAuction(address(erc721), TOKEN_ID);
    createAuction(TOKEN_ID);
  }

  function testCannotEndAuctionBeforeEndOfBid() external {
    ConfidentialAuction.Auction memory beforeAuction = createAuction(TOKEN_ID);

    bytes memory expectError = bytes.concat(
      bytes("BidPeriodOngoingError("),
      bytes(block.timestamp.toString()),
      bytes(", "),
      bytes(beforeAuction.endOfBiddingPeriod.toString()),
      bytes(")"));

    console2.log(string(expectError));
    vm.expectRevert(expectError);

    auction.endAuction(address(erc721), TOKEN_ID);
  }





//-------------------------------------------------------------------

  function doBid(uint256 tokenId, uint256 amount)
    private 
    returns (ConfidentialAuction.BidInfo memory info)
  {
    hoax(alice, PRANK_GIVE);
    auction.bid{value: amount}(address(erc721), tokenId);
    return auction.getBidInfo(alice);
  }

  function assertBidEqual(
      ConfidentialAuction.BidInfo memory actualInfo,
      ConfidentialAuction.BidInfo memory expectedInfo
  ) private pure {
      assertEq(actualInfo.bidValue, expectedInfo.bidValue, "bidValue");
      assertEq(actualInfo.tokenContract, expectedInfo.tokenContract, "tokenContract");
      assertEq(actualInfo.tokenId, expectedInfo.tokenId, "tokenId");
  }

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
  ) private pure {
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