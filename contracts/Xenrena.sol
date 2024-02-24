// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/Math.sol";
//import "@chainlink/contracts/src/v0.8/dev/ChainlinkClient.sol";

contract Xenrena   {
    address public owner;
    using Math for uint256;

    enum PredictionOutcome { NotSet, OptionA, OptionB }
    enum PredictionCategory { eSports, Sports, Finance, Politics, Fighting, Racing, Adventure, Cards }
    enum MarketStatus { Open, Concluded, Canceled }

    struct PredictionMarket {
        bool concluded;
        PredictionOutcome outcome;
        uint256 totalStakeOptionA;
        uint256 totalStakeOptionB;
        PredictionCategory category;
    }

    PredictionMarket[] public predictionMarkets;

    struct PredictionRecord {
        uint256 stakedAmount;
        PredictionOutcome predictedOutcome;
        PredictionOutcome actualOutcome;
        bool rewarded;
    }

    event PredictionMarketConcluded(uint256 indexed marketId);

    struct UserProfile {
        uint256 totalStakedAmount;
        uint256 totalRewards;
        bytes32[] participatedMarkets;
        bytes32[] rewardedMarkets;
    }

    mapping(address => UserProfile) public userProfiles;

    mapping(uint256 => mapping(address => uint256)) public userStakes;
    mapping(uint256 => PredictionRecord) public userPredictionHistory;

    struct Notification {
        string message;
        uint256 timestamp;
    }

    mapping(address => Notification[]) public userNotifications;
    mapping(address => bool) public isAdmin;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier marketNotConcluded(uint256 _marketId) {
        require(!predictionMarkets[_marketId].concluded, "Prediction market already concluded");
        _;
    }

    modifier onlyOwnerOrAdmin() {
        require(msg.sender == owner || isAdmin[msg.sender], "Not the owner or admin");
        _;
    }

    constructor() {
        owner = msg.sender;
        isAdmin[msg.sender] = true;
    }

    function addAdmin(address _admin) external onlyOwner {
        isAdmin[_admin] = true;
    }

    function removeAdmin(address _admin) external onlyOwner {
        isAdmin[_admin] = false;
    }

    function emitNotification(address _user, string memory _message) internal {
        userNotifications[_user].push(Notification({
            message: _message,
            timestamp: block.timestamp
        }));
    }

    function createPredictionMarket(PredictionCategory _category) external onlyOwner returns (uint256) {
        predictionMarkets.push(PredictionMarket({
            concluded: false,
            outcome: PredictionOutcome.NotSet,
            totalStakeOptionA: 0,
            totalStakeOptionB: 0,
            category: _category
        }));

        uint256 newMarketId = predictionMarkets.length - 1;
        return newMarketId;
    }

    function stakeTokens(uint256 _marketId, PredictionOutcome _prediction) external payable {
        require(msg.value > 0, "Staked amount must be greater than 0");
        require(_prediction == PredictionOutcome.OptionA || _prediction == PredictionOutcome.OptionB, "Invalid prediction");

        PredictionMarket storage market = predictionMarkets[_marketId];
        require(!market.concluded, "Prediction market already concluded");

        // Update total stake for the chosen option
        if (_prediction == PredictionOutcome.OptionA) {
            market.totalStakeOptionA = market.totalStakeOptionA +=(msg.value);
        } else {
            market.totalStakeOptionB = market.totalStakeOptionB +=(msg.value);
        }

        // Update user's stake for the chosen market and option
        userStakes[_marketId][msg.sender] = userStakes[_marketId][msg.sender] += (msg.value);

        // Update user's prediction history
        userPredictionHistory[_marketId] = PredictionRecord({
            stakedAmount: msg.value,
            predictedOutcome: _prediction,
            actualOutcome: PredictionOutcome.NotSet, // Set to NotSet initially
            rewarded: false
        });

        emitNotification(msg.sender, "Tokens staked successfully");
    }

    function getUserPredictionHistory(uint256 _marketId) external view returns (uint256 stakedAmount, PredictionOutcome predictedOutcome, PredictionOutcome actualOutcome, bool rewarded) {
        PredictionRecord memory predictionRecord = userPredictionHistory[_marketId];
        return (predictionRecord.stakedAmount, predictionRecord.predictedOutcome, predictionRecord.actualOutcome, predictionRecord.rewarded);
    }

    function getUserOverallPerformance() external view returns (uint256 totalStakedAmount, uint256 totalRewards) {
        for (uint256 i = 0; i < predictionMarkets.length; i++) {
            PredictionRecord memory predictionRecord = userPredictionHistory[i];

            if (predictionRecord.stakedAmount > 0 && !predictionRecord.rewarded) {
                totalStakedAmount = totalStakedAmount +=(predictionRecord.stakedAmount);

                // Call calculateRewards only for records that haven't been rewarded yet
                totalRewards = totalRewards +=(calculateRewards(
                    predictionRecord.stakedAmount,
                    predictionRecord.predictedOutcome,
                    predictionRecord.actualOutcome,
                    predictionMarkets[i].totalStakeOptionA,
                    predictionMarkets[i].totalStakeOptionB
                ));
            }
        }

        return (totalStakedAmount, totalRewards);
    }

    function calculateRewards(
    uint256 _stakedAmount,
    PredictionOutcome _predictedOutcome,
    PredictionOutcome _actualOutcome,
    uint256 _totalStakeOptionA,
    uint256 _totalStakeOptionB
) internal pure returns (uint256) {
    // Placeholder logic for reward calculation
    // Replace this with your actual reward distribution logic based on the predicted and actual outcomes

    uint256 totalStaked = _totalStakeOptionA + _totalStakeOptionB;

    if (_predictedOutcome == _actualOutcome) {
        if (_predictedOutcome == PredictionOutcome.OptionA) {
            // Use standard multiplication operator
            return (_stakedAmount * _totalStakeOptionA) / totalStaked;
        } else {
            // Use standard multiplication operator
            return (_stakedAmount * _totalStakeOptionB) / totalStaked;
        }
    }

    return 0; // No reward if prediction is incorrect
}


    function distributeRewards(uint256 _marketId, PredictionOutcome _actualOutcome) external onlyOwner marketNotConcluded(_marketId) {
        PredictionMarket storage market = predictionMarkets[_marketId];
        require(market.concluded, "Prediction market not concluded");

        for (uint256 i = 0; i < predictionMarkets.length; i++) {
            PredictionRecord storage predictionRecord = userPredictionHistory[i];

            if (predictionRecord.stakedAmount > 0 && !predictionRecord.rewarded) {
                // Calculate rewards based on the actual outcome
                uint256 userReward = calculateRewards(
                    predictionRecord.stakedAmount,
                    predictionRecord.predictedOutcome,
                    _actualOutcome,
                    market.totalStakeOptionA,
                    market.totalStakeOptionB
                );

                // Distribute rewards to the user
                if (userReward > 0) {
                    payable(msg.sender).transfer(userReward);
                    predictionRecord.rewarded = true;
                }
            }
        }

        // Mark the prediction market as concluded
        market.concluded = true;
        market.outcome = _actualOutcome;

        emit PredictionMarketConcluded(_marketId);
    }

    function getOpenMarkets() external view returns (bytes32[] memory) {
        bytes32[] memory openMarkets = new bytes32[](predictionMarkets.length);
        uint256 openMarketsCount = 0;

        for (uint256 i = 0; i < predictionMarkets.length; i++) {
            if (!predictionMarkets[i].concluded) {
                openMarkets[openMarketsCount] = bytes32(i);
                openMarketsCount++;
            }
        }

        // Resize the array to remove any unused slots
        assembly {
            mstore(openMarkets, openMarketsCount)
        }

        return openMarkets;
    }

    function getMarketDetails(bytes32 marketId) external view returns (uint256 outcomeA, uint256 outcomeB, MarketStatus status, PredictionCategory category) {
        PredictionMarket storage market = predictionMarkets[uint256(marketId)];
        return (market.totalStakeOptionA, market.totalStakeOptionB, market.concluded ? MarketStatus.Concluded : MarketStatus.Open, market.category);
    }

    function getUserPredictions() external view returns (bytes32[] memory markets, uint256[] memory outcomes, uint256[] memory stakes) {
        bytes32[] memory userMarkets = new bytes32[](predictionMarkets.length);
        uint256[] memory userOutcomes = new uint256[](predictionMarkets.length);
        uint256[] memory userStakesArray = new uint256[](predictionMarkets.length);
        uint256 userMarketsCount = 0;

        for (uint256 i = 0; i < predictionMarkets.length; i++) {
            PredictionRecord storage predictionRecord = userPredictionHistory[i];

            if (predictionRecord.stakedAmount > 0) {
                userMarkets[userMarketsCount] = bytes32(i);
                userOutcomes[userMarketsCount] = uint256(predictionRecord.predictedOutcome);
                userStakesArray[userMarketsCount] = predictionRecord.stakedAmount;
                userMarketsCount++;
            }
        }

        // Resize the arrays to remove any unused slots
        assembly {
            mstore(userMarkets, userMarketsCount)
            mstore(userOutcomes, userMarketsCount)
            mstore(userStakesArray, userMarketsCount)
        }

        return (userMarkets, userOutcomes, userStakesArray);
    }

    function getUserRewards() external view returns (bytes32[] memory markets, uint256[] memory rewards) {
        bytes32[] memory rewardedMarkets = new bytes32[](predictionMarkets.length);
        uint256[] memory rewardAmounts = new uint256[](predictionMarkets.length);
        uint256 rewardedMarketsCount = 0;

        for (uint256 i = 0; i < predictionMarkets.length; i++) {
            PredictionRecord storage predictionRecord = userPredictionHistory[i];

            if (predictionRecord.rewarded) {
                rewardedMarkets[rewardedMarketsCount] = bytes32(i);
                rewardAmounts[rewardedMarketsCount] = calculateRewards(
                    predictionRecord.stakedAmount,
                    predictionRecord.predictedOutcome,
                    predictionRecord.actualOutcome,
                    predictionMarkets[i].totalStakeOptionA,
                    predictionMarkets[i].totalStakeOptionB
                );
                rewardedMarketsCount++;
            }
        }

        // Resize the arrays to remove any unused slots
        assembly {
            mstore(rewardedMarkets, rewardedMarketsCount)
            mstore(rewardAmounts, rewardedMarketsCount)
        }

        return (rewardedMarkets, rewardAmounts);
    }

    function isMarketEligible(bytes32 marketId) external view returns (bool) {
        PredictionMarket storage market = predictionMarkets[uint256(marketId)];
        return !market.concluded;
    }

    function getAllParticipants(bytes32 marketId) external view returns (address[] memory) {
        PredictionRecord storage predictionRecord = userPredictionHistory[uint256(marketId)];
        address[] memory participants = new address[](2); // Assuming a maximum of two participants (OptionA and OptionB)
        uint256 participantCount = 0;

        if (predictionRecord.stakedAmount > 0) {
            participants[participantCount] = msg.sender;
            participantCount++;
        }

        // Resize the array to remove any unused slots
        assembly {
            mstore(participants, participantCount)
        }

        return participants;
    }

    function getMarketCategory(bytes32 marketId) external view returns (PredictionCategory) {
        PredictionMarket storage market = predictionMarkets[uint256(marketId)];
        return market.category;
    }
    
    function getTotalStakedTokens() external view returns (uint256) {
    uint256 totalStakedTokens = 0;

    for (uint256 i = 0; i < predictionMarkets.length; i++) {
        totalStakedTokens += (predictionMarkets[i].totalStakeOptionA) + (predictionMarkets[i].totalStakeOptionB);
    }

    return totalStakedTokens;
}


    function claimReward(uint256 _marketId) external {
        PredictionRecord storage predictionRecord = userPredictionHistory[_marketId];

        require(predictionRecord.stakedAmount > 0, "No stake found for the given market");
        require(!predictionRecord.rewarded, "Reward already claimed for this market");

        PredictionMarket storage market = predictionMarkets[_marketId];
        require(market.concluded, "Market must be concluded to claim rewards");

        uint256 userReward = calculateRewards(
            predictionRecord.stakedAmount,
            predictionRecord.predictedOutcome,
            predictionRecord.actualOutcome,
            market.totalStakeOptionA,
            market.totalStakeOptionB
        );

        require(userReward > 0, "No rewards available for claiming");

        // Transfer the rewards to the user
        payable(msg.sender).transfer(userReward);

        // Mark the prediction as rewarded
        predictionRecord.rewarded = true;

        emitNotification(msg.sender, "Rewards claimed successfully");
    }

    function getUserStakedAmount(uint256 _marketId) external view returns (uint256) {
        return userStakes[_marketId][msg.sender];
    }

    function withdrawStakedTokens(uint256 _marketId) external {
        PredictionMarket storage market = predictionMarkets[_marketId];
        PredictionRecord storage predictionRecord = userPredictionHistory[_marketId];

        require(predictionRecord.stakedAmount > 0, "No stake found for the given market");
        require(!market.concluded, "Cannot withdraw from a concluded market");
        require(!predictionRecord.rewarded, "Tokens already withdrawn or rewards claimed");

        // Transfer staked tokens back to the user
        payable(msg.sender).transfer(predictionRecord.stakedAmount);

        // Update total stake for the chosen option
        if (predictionRecord.predictedOutcome == PredictionOutcome.OptionA) {
            market.totalStakeOptionA -= predictionRecord.stakedAmount;
        } else {
            market.totalStakeOptionB -= predictionRecord.stakedAmount;
        }

        // Update user's stake for the chosen market and option
        userStakes[_marketId][msg.sender] = 0;

        // Mark the prediction as withdrawn
        predictionRecord.stakedAmount = 0;

        emitNotification(msg.sender, "Staked tokens withdrawn successfully");
    }

    function closeMarket(uint256 _marketId) external onlyOwnerOrAdmin {
        PredictionMarket storage market = predictionMarkets[_marketId];
        require(!market.concluded, "Prediction market already concluded");

        // Mark the market as concluded
        market.concluded = true;

        emit PredictionMarketConcluded(_marketId);
    }

    function cancelMarket(uint256 _marketId) external onlyOwnerOrAdmin {
        PredictionMarket storage market = predictionMarkets[_marketId];
        require(!market.concluded, "Prediction market already concluded");

        // Refund staked tokens to all participants
        for (uint256 i = 0; i < predictionMarkets.length; i++) {
            PredictionRecord storage predictionRecord = userPredictionHistory[_marketId];

            if (predictionRecord.stakedAmount > 0) {
                // Transfer staked tokens back to the user
                payable(msg.sender).transfer(predictionRecord.stakedAmount);

                // Mark the prediction as canceled
                predictionRecord.stakedAmount = 0;
                predictionRecord.rewarded = true;
            }
        }

        // Mark the market as canceled
        market.concluded = true;
        market.outcome = PredictionOutcome.NotSet;

        emit PredictionMarketConcluded(_marketId);
    }

    function resolveMarket(uint256 _marketId, PredictionOutcome _actualOutcome) external onlyOwnerOrAdmin {
        PredictionMarket storage market = predictionMarkets[_marketId];
        require(!market.concluded && market.totalStakeOptionA + market.totalStakeOptionB > 0, "Cannot resolve an empty or concluded market");

        // Mark the market as concluded
        market.concluded = true;
        market.outcome = _actualOutcome;

        // Distribute rewards to participants
        for (uint256 i = 0; i < predictionMarkets.length; i++) {
            PredictionRecord storage predictionRecord = userPredictionHistory[i];

            if (predictionRecord.stakedAmount > 0 && !predictionRecord.rewarded) {
                uint256 userReward = calculateRewards(
                    predictionRecord.stakedAmount,
                    predictionRecord.predictedOutcome,
                    _actualOutcome,
                    market.totalStakeOptionA,
                    market.totalStakeOptionB
                );

                // Transfer the rewards to the user
                if (userReward > 0) {
                    payable(msg.sender).transfer(userReward);
                }

                // Mark the prediction as rewarded
                predictionRecord.rewarded = true;
            }
        }

        emit PredictionMarketConcluded(_marketId);
    }

    function getAllWinners(uint256 _marketId) external view returns (address[] memory winners) {
        PredictionMarket storage market = predictionMarkets[_marketId];
        require(market.concluded, "Market must be concluded");

        uint256 totalWinners = 0;

        for (uint256 i = 0; i < predictionMarkets.length; i++) {
            PredictionRecord storage predictionRecord = userPredictionHistory[i];

            if (predictionRecord.stakedAmount > 0 && predictionRecord.actualOutcome == market.outcome) {
                totalWinners++;
            }
        }

        winners = new address[](totalWinners);
        uint256 winnerIndex = 0;

        for (uint256 i = 0; i < predictionMarkets.length; i++) {
            PredictionRecord storage predictionRecord = userPredictionHistory[i];

            if (predictionRecord.stakedAmount > 0 && predictionRecord.actualOutcome == market.outcome) {
                winners[winnerIndex] = msg.sender;
                winnerIndex++;
            }
        }

        return winners;
    }

    function getUserProfile() external view returns (uint256 totalStakedAmount, uint256 totalRewards, bytes32[] memory participatedMarkets, bytes32[] memory rewardedMarkets) {
        UserProfile storage userProfile = userProfiles[msg.sender];

        totalStakedAmount = userProfile.totalStakedAmount;
        totalRewards = userProfile.totalRewards;
        participatedMarkets = userProfile.participatedMarkets;
        rewardedMarkets = userProfile.rewardedMarkets;
    }
}
