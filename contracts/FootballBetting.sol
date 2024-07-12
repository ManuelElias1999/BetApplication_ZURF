// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract FootballBetting {
    address private constant FEE_ADDRESS = 0xD7bF67d127Ea9c7F58122E965F2F7aE8f1b5032E;
    address private constant BONSAI_TOKEN_ADDRESS = 0x3d2bD0e15829AA5C362a4144FdF4A1112fa29B5c;
    uint256 private minimumBetAmount;

    struct Bet {
        address bettor;
        uint256 amount;
    }

    struct BetInstance {
        string id;
        string option1;
        string option2;
        uint256 totalAmountOption1;
        uint256 totalAmountOption2;
        mapping(address => Bet) betsoption1;
        mapping(address => Bet) betsoption2;
        address[] bettorsoption1;
        address[] bettorsoption2;
        address creator;
        bool isClosed;
        bool isResolved;
    }

    mapping(string => BetInstance) private betInstances;
    IERC20 private bonsaiToken;

    event BetInstanceCreated(address creator, string indexed betId, string option1, string option2, uint256 minimumBetAmount);
    event BetPlaced(string indexed betId, address indexed bettor, uint256 amount, uint8 team);
    event BettingClosed(string indexed betId);
    event BettingResolved(string indexed betId, uint8 winningTeam);

    modifier onlyCreator(string memory _betId) {
        require(msg.sender == betInstances[_betId].creator, "Not authorized");
        _;
    }

    constructor() {
        bonsaiToken = IERC20(BONSAI_TOKEN_ADDRESS);
    }

    function createBetInstance(string calldata _betId, string calldata _option1, string calldata _option2, uint256 _minimumBetAmount) external {
        require(bytes(betInstances[_betId].id).length == 0, "Bet instance with this ID already exists");

        BetInstance storage newInstance = betInstances[_betId];
        newInstance.id = _betId;
        newInstance.option1 = _option1;
        newInstance.option2 = _option2;
        newInstance.creator = msg.sender;
        minimumBetAmount = _minimumBetAmount;
        emit BetInstanceCreated(msg.sender, _betId, _option1, _option2, _minimumBetAmount);
    }

    function placeBetOnoption1(string calldata _betId, uint256 _amount) external {
        BetInstance storage betInstance = betInstances[_betId];
        require(!betInstance.isClosed, "Betting is closed");
        require(_amount >= minimumBetAmount, "Bet amount is less than minimum");

        require(bonsaiToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        betInstance.totalAmountOption1 += _amount;
        betInstance.betsoption1[msg.sender] = Bet(msg.sender, _amount);
        betInstance.bettorsoption1.push(msg.sender);
        
        emit BetPlaced(_betId, msg.sender, _amount, 1);
    }

    function placeBetOnoption2(string calldata _betId, uint256 _amount) external {
        BetInstance storage betInstance = betInstances[_betId];
        require(!betInstance.isClosed, "Betting is closed");
        require(_amount >= minimumBetAmount, "Bet amount is less than minimum");

        require(bonsaiToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        betInstance.totalAmountOption2 += _amount;
        betInstance.betsoption2[msg.sender] = Bet(msg.sender, _amount);
        betInstance.bettorsoption2.push(msg.sender);

        emit BetPlaced(_betId, msg.sender, _amount, 2);
    }

    function closeBetting(string calldata _betId) external onlyCreator(_betId) {
        BetInstance storage betInstance = betInstances[_betId];
        betInstance.isClosed = true;
        emit BettingClosed(_betId);
    }

    function openBetting(string calldata _betId) external onlyCreator(_betId) {
        BetInstance storage betInstance = betInstances[_betId];
        betInstance.isClosed = false;
    }

    function getTotalAmounts(string calldata _betId) external view returns (uint256 total, uint256 totaloption1, uint256 totaloption2, bool isClosed, bool isResolved) {
        BetInstance storage betInstance = betInstances[_betId];
        totaloption1 = betInstance.totalAmountOption1;
        totaloption2 = betInstance.totalAmountOption2;
        total = totaloption1 + totaloption2;
        isClosed = betInstance.isClosed;
        isResolved = betInstance.isResolved;
    }

    function distributeWinnings(string calldata _betId, uint8 _winningTeam) external onlyCreator(_betId) {
        require(_winningTeam == 1 || _winningTeam == 2, "Invalid winning team");

        BetInstance storage betInstance = betInstances[_betId];
        require(betInstance.isClosed && !betInstance.isResolved, "Betting must be closed and not resolved");

        uint256 totalAmountToDistribute = betInstance.totalAmountOption1 + betInstance.totalAmountOption2;
        uint256 totalAmountWinningTeam;

        // Determinar el total apostado en el equipo ganador
        if (_winningTeam == 1) {
            require(betInstance.totalAmountOption1 > 0, "No bets on Team 1");
            totalAmountWinningTeam = betInstance.totalAmountOption1;
        } else {
            require(betInstance.totalAmountOption2 > 0, "No bets on Team 2");
            totalAmountWinningTeam = betInstance.totalAmountOption2;
        }

        // Calcular y transferir el 1% del total al FEE_ADDRESS y al creador
        uint256 fee = totalAmountToDistribute / 100;
        uint256 creatorFee = fee;
        uint256 remainingAmount = totalAmountToDistribute - fee - creatorFee;
        
        require(bonsaiToken.transfer(FEE_ADDRESS, fee), "Fee transfer failed");
        require(bonsaiToken.transfer(betInstance.creator, creatorFee), "Creator fee transfer failed");

        // Calcular y transferir los fondos a los ganadores
        address[] memory winners = (_winningTeam == 1) ? betInstance.bettorsoption1 : betInstance.bettorsoption2;
        for (uint256 i = 0; i < winners.length; i++) {
            address winner = winners[i];
            uint256 betAmount = (_winningTeam == 1) ? betInstance.betsoption1[winner].amount : betInstance.betsoption2[winner].amount;

            // Calcular el porcentaje de la apuesta del ganador respecto al total del equipo ganador
            uint256 amountToTransfer = (betAmount * remainingAmount) / totalAmountWinningTeam;

            require(bonsaiToken.transfer(winner, amountToTransfer), "Winner transfer failed");
        }

        betInstance.isResolved = true;
        emit BettingResolved(_betId, _winningTeam);
    }
}