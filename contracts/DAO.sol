// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DAO {
    enum Side {
        Yes,
        No
    }
    enum Status {
        Undecided,
        Approved,
        Rejected
    }
    struct Proposal {
        address author;
        bytes32 hash;
        uint256 createdAt;
        uint256 votesYes;
        uint256 votesNo;
        Status status;
    }

    mapping(bytes32 => Proposal) public proposals;
    //check if user already voted so there is not double votes
    mapping(address => mapping(bytes32 => bool)) public votes;
    //1 share per governance token
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    IERC20 public token;
    //min amount of governance tokens someone must have to create a proposal
    uint256 constant CREATE_PROPOSAL_MIN_SHARE = 20 * 10**18;
    uint256 constant VOTING_PERIOD = 30 minutes;

    constructor(address _token) {
        token = IERC20(_token);
    }

    //before voting we need to deposit
    function deposit(uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        shares[msg.sender] += amount;
        totalShares += amount;
    }

    function withdraw(uint256 amount) external {
        require(shares[msg.sender] >= amount, "not enough shares");
        shares[msg.sender] -= amount;
        totalShares -= amount;
        token.transfer(msg.sender, amount);
    }

    function createProposal(bytes32 proposalHash) external {
        require(
            shares[msg.sender] >= CREATE_PROPOSAL_MIN_SHARE,
            "not enough shares to create proposal"
        );
        require(
            proposals[proposalHash].hash == bytes32(0),
            "this proposal already exist"
        );
        proposals[proposalHash] = Proposal(
            msg.sender,
            proposalHash,
            block.timestamp,
            0,
            0,
            Status.Undecided
        );
    }

    function vote(bytes32 proposalHash, Side side) external {
        Proposal storage proposal = proposals[proposalHash];
        require(votes[msg.sender][proposalHash] == false, "already voted");
        require(
            proposals[proposalHash].hash != bytes32(0),
            "proposal already exist"
        );
        require(
            block.timestamp <= proposal.createdAt + VOTING_PERIOD,
            "voting period over"
        );
        votes[msg.sender][proposalHash] = true;
        if (side == Side.Yes) {
            proposal.votesYes += shares[msg.sender];
            //votes are multiplied because we want to have more than 50% of the votes, which
            // would be 0.5 but solidity cant handle floats, so we go around it
            if ((proposal.votesYes * 100) / totalShares > 50) {
                proposal.status = Status.Approved;
            }
        } else {
            proposal.votesNo += shares[msg.sender];
            if ((proposal.votesNo * 100) / totalShares > 50) {
                proposal.status = Status.Rejected;
            }
        }
    }
}
