// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IERC20 {
    function Transfer(address, uint256) external returns (bool);
    function TransferFrom(address, address, uint256) external returns (bool);
}

contract CrowdFund {
    event Launch(
        uint256 id,
        address indexed creater,
        uint256 goal,
        uint32 startAT,
        uint32 endAT
    );
    event Cancel(uint256 id);
    event Pledge(uint256 indexed id, address indexed caller, uint256 amount);
    event Unpledge(uint256 indexed id, address indexed caller, uint256 amount);
    event Claim(uint256 id);
    event Refund(uint256 id, address indexed caller, uint256 amount);

    struct Campaign {
        // Creater of campaign
        address creater;
        // Amount of tokens to raise
        uint256 goal;
        // Total amount pledged
        uint256 pledged;
        // TimeStamp of start of campaign
        uint32 startAT;
        // TimeStamp of end of campaign
        uint32 endAT;
        // True if goal was reached and creator has claimed the tokens.
        bool claimed;
    }

    IERC20 immutable token;
    // Total count of campaigns created.
    // It is also used to generate id for new campaigns.
    uint256 public count;
    // Mapping from campaign id to campaign details
    mapping(uint256 => Campaign) public campaigns;
    // Mapping from campaign id => mapping of pledger address => amount pledged
    mapping(uint256 => mapping(address => uint256)) public pledgedAmount;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function launch(uint256 _goal, uint32 _startAt, uint32 _endAt) external {
        require(_startAt >= block.timestamp, "Start at < now");
        require(_endAt >= _startAt, "end at < start at");
        require(_endAt <= block.timestamp + 90 days, "end at > max duration");

        count += 1;
        campaigns[count] = Campaign({
            creater: msg.sender,
            goal: _goal,
            pledged: 0,
            startAT: _startAt,
            endAT: _endAt,
            claimed: false
        });

        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }

    function cancel(uint256 _id) external {
        Campaign memory campaign = campaigns[_id];
        require(campaign.creater == msg.sender, "not creater");
        require(block.timestamp < campaign.startAT, "started");

        delete campaigns[_id];
        emit Cancel(_id);
    }

    function pledge(uint256 _id, uint256 _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startAT, "not started");
        require(block.timestamp <= campaign.endAT, "ended");

        campaign.pledged += _amount;
        pledgedAmount[_id][msg.sender] += _amount;
        token.TransferFrom(msg.sender, address(this), _amount);

        emit Pledge(_id, msg.sender, _amount);
    }

    function unpledge(uint256 _id, uint256 _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= campaign.endAT, "ended");

        campaign.pledged -= _amount;
        pledgedAmount[_id][msg.sender] -= _amount;
        token.Transfer(msg.sender, _amount);

        emit Unpledge(_id, msg.sender, _amount);
    }

    function claim(uint256 _id) external {
        Campaign memory campaign = campaigns[_id];
        require(campaign.creater == msg.sender, "not creater");
        require(block.timestamp > campaign.endAT, "not ended");
        require(campaign.pledged >= campaign.goal, "pledged < goal");
        require(!campaign.claimed, "claimed");

        campaign.claimed = true;
        token.Transfer(campaign.creater, campaign.pledged);

        emit Claim(_id);
    }

    function refund(uint256 _id) external {
        Campaign memory campaign = campaigns[_id];
        require(block.timestamp > campaign.endAT, "not ended");
        require(campaign.pledged < campaign.goal, "pledged >= goal");

        uint256 bal = pledgedAmount[_id][msg.sender];
        pledgedAmount[_id][msg.sender] = 0;
        token.Transfer(msg.sender, bal);

        emit Refund(_id, msg.sender, bal);
    }
}
