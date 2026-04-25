// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.33;

// Custom errors for ConfidentialAuction
interface IConfidentialAuctionErrors {
    error BidPeriodOngoingError(uint256 currentTimestamp, uint256 endOfBiddingPeriod);
    error BidPeriodTooShortError(uint32 bidPeriod);
    error NotInBidPeriodError();
    error InvalidTokenContractError();
    error InvalidBidError(uint256 bid);
    error NoRefundBalanceError();
    error NoNeedEndAuction();
}