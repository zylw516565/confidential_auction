// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.33;

// Custom errors for ConfidentialAuction
interface IConfidentialAuctionErrors {
    error BidPeriodOngoingError(uint256 currentTimestamp, uint256 endOfBiddingPeriod);
    error InvalidAuctionIndexError(uint32 index);
    error BidPeriodTooShortError(uint32 bidPeriod);
    error NotInBidPeriodError();
    error NotInRevealPeriodError();
    error IncorrectVaultAddressError(address expectedVault, address actualVault);
    error UnrevealedBidError();
    error CannotWithdrawError();
    error BidAlreadyRevealedError(address vault);
    error InvalidTokenContractError();
    error InvalidBidError(uint256 bid);
    error InefficiencyBalanceError(uint256 balance, uint256 amount);
    error NoRefundBalanceError();
    error NoNeedEndAuction();
}