// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.10;



struct Pool {
    uint256 startBlock;
    uint256 endBlock;
    uint256 startEpoch;
    uint256 currentEpoch;
    address stakeToken;
    address rewardToken;
    uint256 rewardPerBlock;
    uint256 rewardperBlockPerCoin;
    uint256 totalNumberOfStakers;
    uint256 totalStakedAmount;
    uint256 totalReward;
    uint256 minimumAmount;
}
struct User {
    uint256 startBlock;
    uint256 endBlock;
    uint256 totalStakedAmount;
    uint256 startEpoch;
    uint256 endEpoch;
    uint256 pastReward;
    uint256 lastStakingTime;
}

interface StakingInterFace {
    function pools(bytes32 map) external view returns (Pool memory);

    function users(bytes32 map, address user)
        external
        view
        returns (User memory);
}

interface PermisssionInterface {
    /** @notice interface to update account status
        this can be executed by org admin accounts only
      * @param _orgId unique id of the organization to which the account belongs
      * @param _account account id
      * @param _action 1-suspending 2-activating back 3-blacklisting
      */
    function updateAccountStatus(
        string calldata _orgId,
        address _account,
        uint256 _action
    ) external;
}

struct Proposal {
    uint256 id;
    string detailsURI;
    address[] addressToBlockFor;
    address[] addressToBlockAgainst;
    address[] addressToWhitelistFor;
    address[] addressToWhitelistAgainst;
    uint256 votedFor;
    uint256 votedAgainst;
    uint256 startTime;
    uint256 endTime;
    bytes32 action;
    bytes32 result;
    uint256 amount;
    address payable transferToAddress;
    address[] removedDaoAddress;
    address ownerProposal_;
}

struct CommunityProposal {
    uint256 id;
    string detailsURI;
    uint256 votedFor;
    uint256 votedAgainst;
    uint256 startTime;
    uint256 endTime;
    uint256 minimumStakingTime;
    bytes32 result;
    address ownerProposal_;
}

struct VotedStruct {
    uint256 proposalId;
    address voter;
    uint256 timestamp;
    bool choosen;
}

struct CommunityVotedStruct {
    uint256 proposalId;
    address _voter;
    uint256 timestamp;
    bool choosen;
}

struct Concern {
    uint256 ticketId;
    address memberAddress;
    string reasonURI; // UNSATISFACTORY ||
    uint256 proposalId; // DAO PROPOSAL ID
    bytes32 status; // PENDING || RESOLVED || REJECTED
    string rejectReason;
    string resolveReason;
}

contract DAO  {
    address public owner;

    // Store Info About Dao and Panel Members
    address[] public daoMembers;
    address[] public panelMembers;

    mapping(address => bool) public isPanelMember;
    mapping(address => bool) public isDaoMember;
    mapping(address => bool) public isOwner;

    mapping(address => uint256) private daoMemberIndex;
    mapping(address => uint256) private panelMemberIndex;

    // VotedStruct[] public votedOn_;

    mapping(uint256 => VotedStruct[]) public votes;
    mapping(uint256 => mapping(address => VotedStruct)) public isVoted;
    mapping(uint256 => CommunityVotedStruct[]) public communityVotedOn;
    mapping(uint256 => mapping(address => CommunityVotedStruct))
        public isCommunityVoted;

    // Permissioned Interface of the chain
    PermisssionInterface immutable permissionInterfaceContract;

    // Staking Pool Info
    StakingInterFace stakingContract;
    bytes32 stakingMap;

    // MAIN ORG OF THE CHAIN
    string _orgId = "ADMINORG";

    uint256 public concernTicket;

    // Proposal
    // ;
    Proposal[] public proposals;
    CommunityProposal[] public communityProposals;
    mapping(uint256 => Proposal) private proposal;

    Concern[] public raiseConcern;

    uint256 public minVote;

    // uint256 numOfRaiseConcern;

    mapping(uint256 => CommunityProposal) private communityProposal;
    mapping(uint256 => Concern) private raiseConcern_;

    //voted

    //event
    event ProposalCreated(
        uint256 indexed id,
        address indexed proposerAddr,
        string reason,
        uint256 startTime,
        uint256 endTime,
        string action
    );

    event CommunityProposalCreated(
        uint256 indexed id,
        address indexed proposerAddr,
        string reason,
        uint256 startTime,
        uint256 endTime,
        uint256 minimumStakingTime
    );

    event ConcernCreated(
        uint256 indexed concernTicket,
        address indexed memberAddress,
        string reason,
        uint256 proposalId,
        bytes32 pending,
        string rejectReason,
        string resolveReason
    );

    event Voted(
        uint256 indexed proposalId,
        address indexed voterAddress,
        uint256 time,
        string voted
    );
    event VotedCommunity(
        uint256 indexed proposalId,
        address indexed voterAddress,
        uint256 time,
        string voted
    );

    constructor(
        address _interfaceAddr,
        address stakingContractAddress,
        bytes32 stakingMap_
    ) {
        owner = msg.sender;
        addDaoMember(owner);
        permissionInterfaceContract = PermisssionInterface(_interfaceAddr);
        stakingMap = stakingMap_;
        stakingContract = StakingInterFace(stakingContractAddress);
    }

    receive() external payable {}

    modifier onlyOwner() {
        require(msg.sender == owner, "DAO: Admin Only!");
        _;
    }
    modifier onlyMember() {
        require(
            isDaoMember[msg.sender] || isPanelMember[msg.sender],
            "DAO: Member Only!"
        );
        _;
    }

    modifier onlyDaoMember() {
        require(isDaoMember[msg.sender], "DAO: dao member Only!");
        _;
    }
    modifier onlyPanelMember() {
        require(isPanelMember[msg.sender], "DAO: panel member Only!");
        _;
    }

    function addPanelMember(address account) public onlyOwner {
        require(!isPanelMember[account], "DAO: Already a panel member");
        isPanelMember[account] = true;
        panelMemberIndex[account] = panelMembers.length;
        panelMembers.push(account);
    }

    function addDaoMember(address account) public onlyOwner {
        require(!isDaoMember[account], "DAO: Already a member");
        isDaoMember[account] = true;

        daoMemberIndex[account] = daoMembers.length;
        daoMembers.push(account);
    }

    function updateNewAdmin(address newOwner_) public onlyOwner {
        owner = newOwner_;
    }

    function updateVoteLimit(uint256 vote) public onlyOwner {
        minVote = vote;
    }

    function updateStakingDetails(
        address stakingContractAddress,
        bytes32 stakeMap_
    ) public onlyOwner {
        stakingMap = stakeMap_;
        stakingContract = StakingInterFace(stakingContractAddress);
    }

    function removePanelMember(address account) public onlyOwner {
        require(isPanelMember[account], "DAO: not a panel member");
        isPanelMember[account] = false;
        // IF LAST MEMBER OR NOT
        if (panelMemberIndex[account] == (panelMembers.length - 1)) {
            // LAST MEMBER
            panelMembers.pop();
        } else {
            address lastMember = panelMembers[panelMembers.length - 1];
            panelMembers[panelMemberIndex[account]] = lastMember;
            panelMemberIndex[lastMember] = panelMemberIndex[account];
            panelMemberIndex[account] = 0;
            panelMembers.pop();
        }
    }

    function removeDaoMember(address account) internal {
        require(isDaoMember[account], "DAO: not a member");
        isDaoMember[account] = false;
        // IF LAST MEMBER OR NOT
        if (daoMemberIndex[account] == (daoMembers.length - 1)) {
            // LAST MEMBER
            daoMembers.pop();
        } else {
            address lastMember = daoMembers[daoMembers.length - 1];
            daoMembers[daoMemberIndex[account]] = lastMember;
            daoMemberIndex[lastMember] = daoMemberIndex[account];
            daoMemberIndex[account] = 0;
            daoMembers.pop();
        }
    }

    function blackListAddress(address account_) internal {
        permissionInterfaceContract.updateAccountStatus(_orgId, account_, 1);
    }

    function whiteListAddress(address account_) internal {
        permissionInterfaceContract.updateAccountStatus(_orgId, account_, 2);
    }

    uint256 public numOfProposals;

    function createProposal(
        string memory detailsURI,
        address[] memory addressToBlockFor,
        address[] memory addressToBlockAgainst,
        address[] memory addressToWhitelistFor,
        address[] memory addressToWhitelistAgainst,
        string memory action,
        uint256 startTime,
        uint256 endTime,
        uint256 amount,
        address payable transferToAddress,
        address[] memory removeDaoAddress
    ) external onlyMember {
        uint256 proposalId = numOfProposals;
        uint256 time = block.timestamp;
        require(
            startTime > time,
            "Check StartTime"
        );

        require(endTime > startTime && endTime > time && startTime > time, "Check Time");

        if(keccak256(abi.encode(action)) == keccak256(abi.encode("RELEASE AMOUNT"))){
            require(owner == msg.sender,"Only ADMIN ALLOWED");
        }

        proposal[proposalId] = Proposal(
            proposalId,
            detailsURI,
            addressToBlockFor,
            addressToBlockAgainst,
            addressToWhitelistFor,
            addressToWhitelistAgainst,
            0,
            0,
            startTime,
            endTime,
            keccak256(abi.encode(action)),
            keccak256(abi.encode("PENDING")),
            amount,
            transferToAddress,
            removeDaoAddress,
            msg.sender
        );
        proposals.push(proposal[proposalId]);

        emit ProposalCreated(
            proposalId,
            msg.sender,
            detailsURI,
            startTime,
            endTime,
            action
        );

        numOfProposals++;
    }

    uint256 public numofCommunityProposals;

    function createCommunityProposal(
        string memory detailsURI,
        uint256 startTime,
        uint256 endTime,
        uint256 minimumStakingTime
    ) external {
        uint256 minimumAmount = 1000;

        uint256 proposalId = numofCommunityProposals;

        uint256 amount = stakingContract
            .users(stakingMap, msg.sender)
            .totalStakedAmount;

        uint256 time = block.timestamp * 1000;
        require(amount > minimumAmount, "Amount Should Be Greater than 1000"); // Requires more than 1000 CIC Staked.

        require(startTime < time, "Check StartTime"); // Require start time must be more than current blocktime


        startTime = startTime + 20000;

        require(
            endTime > startTime,
            "Check Endtime"
        ); // end blockmust be greater then start block & atleast 20 sec. more

        communityProposal[proposalId] = CommunityProposal(
            proposalId,
            detailsURI,
            0,
            0,
            startTime,
            endTime,
            minimumStakingTime,
            keccak256(abi.encode("PENDING")),
            msg.sender
        );
        communityProposals.push(communityProposal[proposalId]);
        emit CommunityProposalCreated(
            proposalId,
            msg.sender,
            detailsURI,
            startTime,
            endTime,
            minimumStakingTime
        );

        numofCommunityProposals++;
    }

    // By Community
    function raiseAConcern(uint256 proposalId, string memory reason) public {
        // Community member will raise a concern
        address memberAddress = msg.sender;

        raiseConcern.push(
            Concern(
                concernTicket,
                memberAddress,
                reason,
                proposalId,
                keccak256(abi.encode("PENDING")),
                "",
                ""
            )
        );

        emit ConcernCreated(
            concernTicket,
            memberAddress,
            reason,
            proposalId,
            keccak256(abi.encode("PENDING")),
            "",
            ""
        );

        concernTicket += 1;
    }

    function resolveRequest(uint256 DAOProposalID, string memory resolveReason)
        public
    {
        // Panel member will inquire and will create a Proposal to the DAO Board.
        if (
            raiseConcern[DAOProposalID].status ==
            keccak256(abi.encode("PENDING"))
        ) {
            raiseConcern[DAOProposalID].resolveReason = resolveReason;
            raiseConcern[DAOProposalID].status = keccak256(
                abi.encode("RESOLVED")
            );

            //perform any other task
        } 
    }

    function rejectRequest(string memory reasonURI, uint256 DAOProposalID)
        public
    {
        // Reject Concern with a reason
        raiseConcern[DAOProposalID].status = keccak256(abi.encode("REJECTED"));
        raiseConcern[DAOProposalID].rejectReason = reasonURI;
    }

    function endVoting(uint256 proposalId) public onlyDaoMember {
        // Proposal memory proposal_ = proposal[proposalId];
        require(
            proposals[proposalId].result == keccak256(abi.encode("PENDING")),
            "Already Declared Result"
        );

        require(
            proposals[proposalId].ownerProposal_ == msg.sender ||
                msg.sender == owner,
            "Owner & Admin can end this Voting"
        );

        uint256 voteCount = proposals[proposalId].votedFor +
            proposals[proposalId].votedAgainst;

        require(voteCount > minVote, "Minimum Vote Should Be Greater");

        bool wonVoting = false;
        bool draw = false;
        bool lost = false;

        if (
            proposals[proposalId].votedFor > proposals[proposalId].votedAgainst
        ) {
            wonVoting = true;
            proposals[proposalId].result = keccak256(abi.encode("WON"));
        } else if (
            proposals[proposalId].votedFor == proposals[proposalId].votedAgainst
        ) {
            draw = true;
            proposals[proposalId].result = keccak256(abi.encode("DRAW"));
        } else {
            lost = true;
            proposals[proposalId].result = keccak256(abi.encode("LOST"));
        }

        if (draw == false) {
            // Check for Action
            //  WHITELIST
            if (
                proposals[proposalId].action ==
                keccak256(abi.encode("WHITELIST"))
            ) {
                if (wonVoting == true) {
                    for (
                        uint256 i = 0;
                        i < proposals[proposalId].addressToWhitelistFor.length;
                        i++
                    ) {
                        whiteListAddress(
                            proposals[proposalId].addressToWhitelistFor[i]
                        );
                    }
                } else if (wonVoting == false) {
                    for (
                        uint256 i = 0;
                        i <
                        proposals[proposalId].addressToWhitelistAgainst.length;
                        i++
                    ) {
                        whiteListAddress(
                            proposals[proposalId].addressToWhitelistAgainst[i]
                        );
                    }
                }
            } else if (
                proposals[proposalId].action ==
                keccak256(abi.encode("BLACKLIST"))
            ) {
                //         // BLACKLIST
                if (
                    proposals[proposalId].action ==
                    keccak256(abi.encode("BLACKLIST"))
                ) {
                    if (wonVoting == true) {
                        for (
                            uint256 i = 0;
                            i < proposals[proposalId].addressToBlockFor.length;
                            i++
                        ) {
                            blackListAddress(
                                proposals[proposalId].addressToBlockFor[i]
                            );
                        }
                    } else if (wonVoting == false) {
                        for (
                            uint256 i = 0;
                            i <
                            proposals[proposalId].addressToBlockAgainst.length;
                            i++
                        ) {
                            blackListAddress(
                                proposals[proposalId].addressToBlockAgainst[i]
                            );
                        }
                    }
                }
            } else if (
                proposals[proposalId].action ==
                keccak256(abi.encode("RELEASE AMOUNT"))
            ) {
                if (wonVoting == true) {
                    releaseAmount(
                        proposals[proposalId].amount,
                        proposals[proposalId].transferToAddress
                    );
                }
            } else if (
                proposals[proposalId].action ==
                keccak256(abi.encode("REMOVE DAO"))
            ) {
                if (wonVoting == true) {
                    for (
                        uint256 i = 0;
                        i < proposals[proposalId].removedDaoAddress.length;
                        i++
                    ) {
                        removeDaoMember(
                            proposals[proposalId].removedDaoAddress[i]
                        );
                    }
                }
            }
        }
    }

    function releaseAmount(uint256 amount, address payable _toAddress)
        internal
        onlyDaoMember
    {
        uint256 Balance = address(this).balance;
        require(Balance > 0 wei, "No Balance");
        _toAddress.transfer(amount);
        // require(sent == true, "Failed to send");
    }

    function checkBal() public view returns (uint256) {
        uint256 Balance = address(this).balance;
        return Balance;
    }

    function endCommunityVoting(uint256 proposalId) public {
        // communityProposal
        require(
            communityProposals[proposalId].result ==
                keccak256(abi.encode("PENDING")),
            "Already Declared Result"
        );

        uint256 voteCount = communityProposals[proposalId].votedFor +
            communityProposals[proposalId].votedAgainst;

        require(voteCount > minVote, "Min Vote Should Be Greater");

        require(
            communityProposals[proposalId].ownerProposal_ == msg.sender || owner == msg.sender,
            "ONLY OWNER & Admin Can End This Vote"
        );

        if (
            communityProposals[proposalId].votedFor /
                communityProposals[proposalId].votedAgainst >
            1
        ) {
            // WON
            communityProposals[proposalId].result = "WON";
        } else {
            if (
                communityProposals[proposalId].votedFor /
                    communityProposals[proposalId].votedAgainst ==
                1
            ) {
                // DRAW
                communityProposal[proposalId].result = "DRAW";
            } else {
                // Lost
                communityProposal[proposalId].result = "LOST";
            }
        }
    }

    function castAVote(uint256 proposalId, bool isVotingFor)
        public
        onlyDaoMember
    {
        Proposal memory proposal_ = proposals[proposalId];

        //  votedOn[proposalId];
        uint256 time = block.timestamp * 1000;
        address voterAddr = msg.sender;
        // address voter = msg.sender;
        require(!isPanelMember[msg.sender], "PANEL MEMBER: CANNOT VOTE");

        require(
            proposals[proposalId].result == keccak256(abi.encode("PENDING")),
            "Result Already Declared"
        );

        require(
            isVoted[proposalId][msg.sender].voter != msg.sender,
            "Already Voted"
        );

        //     //start time <time< endtime

        require(
            proposal_.endTime > time,
            "Check EndTime"
        );
        require(
            time > proposal_.startTime, // invoke this at the time of production
            "Check StartTime"
        );

        string memory voted;
        if (isVotingFor == true) {
            proposals[proposalId].votedFor += 1;
            voted = "VotedFor";
        } else {
            proposals[proposalId].votedAgainst += 1;
            voted = "VotedAgainst";
        }

        isVoted[proposalId][msg.sender] = VotedStruct(
            proposalId,
            msg.sender,
            time,
            isVotingFor
        );
        votes[proposalId].push(
            VotedStruct(proposalId, msg.sender, time, isVotingFor)
        );

        emit Voted(proposalId, voterAddr, time, voted);
    }

    function castACommunityVote(uint256 proposalId, bool isVotingFor) public {
        uint256 time = block.timestamp * 1000;

        require(communityProposals[proposalId].endTime > time);
        require(communityProposals[proposalId].startTime < time);
        require(
            isCommunityVoted[proposalId][msg.sender]._voter != msg.sender,
            "Already Voted"
        );

        require(
            communityProposals[proposalId].result ==
                keccak256(abi.encode("PENDING")),
            "Result Already Declared"
        );

        require(
            isDaoMember[msg.sender] == false &&
                isPanelMember[msg.sender] == false,
            "NO DAO & PANEL MEMBER PERMISSION"
        ); // must not a dao member or panel member

        //user staked amount > 1000
        uint256 amount = stakingContract
            .users(stakingMap, msg.sender)
            .totalStakedAmount;
        require(amount > 1000);

        string memory voted;

        if (isVotingFor == true) {
            communityProposals[proposalId].votedFor += 1;
            voted = "VoteFor";
        } else {
            communityProposals[proposalId].votedAgainst += 1;
            voted = "VoteFor";
        }

        communityVotedOn[proposalId].push(
            CommunityVotedStruct(
                proposalId,
                msg.sender,
                block.timestamp,
                isVotingFor
            )
        );

        address voterAddr = msg.sender;

        isCommunityVoted[proposalId][msg.sender] = CommunityVotedStruct(
            proposalId,
            msg.sender,
            time,
            isVotingFor
        );

        emit VotedCommunity(proposalId, voterAddr, time, voted);
    }

    function getAllDAOProposals() public view returns (Proposal[] memory) {
        return proposals;
    }

    function getAllCommunityProposals()
        public
        view
        returns (CommunityProposal[] memory)
    {
        return communityProposals;
    }

    function getProposal(
        uint256 proposalId // id starts from 0
    ) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getConcern(
        uint256 ticketId // id starts from 0
    ) external view returns (Concern memory) {
        return raiseConcern[ticketId];
    }

    function getCommunityProposal(uint256 proposalId)
        external
        view
        returns (CommunityProposal memory)
    {
        return communityProposals[proposalId];
    }

    function getVotingResult(uint256 proposalId)
        public
        view
        returns (uint256 VoteFor, uint256 VoteAgainst)
    {
        Proposal memory proposal_ = proposal[proposalId];
        require(proposal_.id == proposalId, "No Proposals");

        return (
            proposals[proposalId].votedFor,
            proposals[proposalId].votedAgainst
        );
    }

    function getCommunityVotingResult(uint256 proposalId)
        public
        view
        returns (uint256 VoteFor, uint256 VoteAgainst)
    {
        CommunityProposal memory proposal_Community = communityProposal[
            proposalId
        ];
        require(proposal_Community.id == proposalId, "No Proposals");

        return (
            communityProposals[proposalId].votedFor,
            communityProposals[proposalId].votedAgainst
        );
    }

    function getProposalEndResult(uint256 proposalId)
        public
        view
        returns (string memory)
    {
        bytes32 result = proposals[proposalId].result;
        string memory str = "";

        if (result == keccak256(abi.encode("WON"))) {
            str = "WON";
        } else if (result == keccak256(abi.encode("LOST"))) {
            str = "LOST";
        } else if (result == keccak256(abi.encode("PENDING"))) {
            str = "PENDING";
        } else if (result == keccak256(abi.encode("DRAW"))) {
            str = "DRAW";
        }

        return str;
    }

    function getCommunityProposalEndResult(uint256 proposalId)
        public
        view
        returns (string memory)
    {
        bytes32 result = communityProposals[proposalId].result;
        string memory str_;

        if (result == keccak256(abi.encode("WON"))) {
            str_ = "WON";
        } else if (result == keccak256(abi.encode("LOST"))) {
            str_ = "LOST";
        } else if (result == keccak256(abi.encode("PENDING"))) {
            str_ = "PENDING";
        } else if (result == keccak256(abi.encode("DRAW"))) {
            str_ = "DRAW";
        }

        return str_;
    }

    function getAllRaiseConcerns() public view returns (Concern[] memory) {
        return raiseConcern;
    }
}
