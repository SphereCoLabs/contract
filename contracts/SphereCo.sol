// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// ERC20 token standard
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// Ownership control
// import "@openzeppelin/contracts/access/Ownable.sol";
// Reentrancy protection
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// Emergency pause functionality
// import "@openzeppelin/contracts/utils/Pausable.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
// import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract SphereCo is ReentrancyGuard {
    // Project Settings
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    
    address public owner;

    // ID counter
    uint256 private campaignIdCounter;
    uint256 private applicationIdCounter;
    uint256 private draftWorkIdCounter;
    uint256 private publishedContentIdCounter;
    uint256 private contentAnalyticIdCounter;

    // Enum campaign status
    enum UserRole {
        Admin,
        Campaigner,
        KOL
    }

    // Enum campaign status
    enum CampaignStatus {
        New,
        Published,
        InProgress,
        ContentDrafted,
        ContentPublished,
        AnalyticShared,
        Cancelled,
        Done
    }

    // Enum Application status
    enum ApplicationStatus {
        Submitted,
        Cancelled,
        Approved,
        Rejected
    }

    enum DraftWorkStatus {
        Submitted,
        Approved,
        Rejected
    }

    struct User {
        string name;
        string summary;
        UserRole role;
    }
    
    enum PaymentStatus {
        Escrowed,
        Released,
        Refunded
    }

    enum campaignPlatform {
        Instagram,
        TikTok,
        YouTube,
        Twitter,
        LinkedIn
    }

    enum campaignContentType {
        Posts,
        Stories,
        Reels,
        Videos,
        LiveStream
    }

    // Campaign struct
    struct Campaign {
        string title;
        string description;

        string brief;
        string goal;
        uint256 startDate;
        uint256 endDate;
        campaignPlatform[] targetPlatform;
        campaignContentType[] contentTypes;
        string targetAudience;
        string guideline;

        uint256 reward;
        CampaignStatus status;
        uint256 createdAt;
        address createdBy;
        uint256 updatedAt;
        address updatedBy;
        address kolWorker;
    }

    struct Application {
        uint256 campaignId;
        address applicantAddress;
        string title;
        string proposal;
        ApplicationStatus status;
    }

    struct DraftWork {
        uint256 campaignId;
        address kolAddress;
        // TODO
        string data;
        DraftWorkStatus status;
    }

    struct PublishedContent {
        uint256 campaignId;
        // TODO
        string data;
        // TODO AI VERIFIED?
    }

    struct ContentAnalytic {
        uint256 campaignId;
        // TODO
        string data;
        // TODO AI VERIFIED?
    }
    
    struct Payment {
        uint256 campaignId;
        uint256 amount;
        PaymentStatus status;
        uint256 escrowedAt;
        uint256 releasedAt;
        uint256 refundedAt;
    }

    uint256[] campaignList;

    // User mapping configurations
    mapping (address => User) users;
    mapping (address => bool) userExists;

    // Campaign mapping configurations
    mapping (uint256 => Campaign) campaigns;
    mapping (uint256 => uint256[]) campaignApplicants;
    mapping(uint256 => mapping(uint256 => bool)) public isApplicantInCampaign;
    mapping (uint256 => bool) campaignExists;
    mapping (uint256 => uint256) campaignEscrow;
    mapping (uint256 => Payment) public campaignPayments;

    // Application mapping configurations
    mapping (uint256 => Application) applications;
    mapping (uint256 => bool) applicationExists;

    // Draft Work mapping configurations
    mapping (uint256 => DraftWork) draftWorks;
    mapping (uint256 => bool) draftWorkExists;
    
    // Published Content mapping configurations
    mapping (uint256 => PublishedContent) publishedContents;
    mapping (uint256 => bool) publishedContentExists;
    
    // Content Analytic mapping configurations
    mapping (uint256 => ContentAnalytic) contentAnalytics;
    mapping (uint256 => bool) contentAnalyticExists;
    
    
    // Events
    event UserRegistered(
        address indexed userAddress,
        uint8 indexed role,
        uint256 timestamp
    );
    event UserUpdated(
        address indexed userAddress,
        uint256 timestamp
    );
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 reward
    );
    event CampaignUpdated(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 reward
    );
    event CampaignCancelled(
        uint256 indexed campaignId,
        address indexed cancelledBy,
        uint256 timestamp
    );
    event CampaignPublished(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 value
    );
    event CampaignCompleted(
        uint256 indexed campaignId
    );
    event RewardWithdrawn(
        uint256 indexed campaignId,
        address indexed kol,
        uint256 value,
        uint256 timestamp
    );
    event RewardRefunded(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 value,
        uint256 timestamp
    );
    event ApplicationSubmitted(
        uint256 indexed campaignId,
        uint256 indexed applicationId,
        address indexed applicator
    );
    event ApplicationApproved(
        uint256 indexed campaignId,
        uint256 indexed applicationId
    );
    event ApplicationRejected(
        uint256 indexed campaignId,
        uint256 indexed applicationId
    );
    event ApplicationCancelled(
        uint256 indexed campaignId,
        uint256 indexed applicationId,
        address indexed applicator
    );
    event DraftWorkSubmitted(
        uint256 indexed campaignId,
        uint256 indexed draftWorkId
    );
    event DraftWorkApproved(
        uint256 indexed campaignId,
        uint256 indexed draftWorkId
    );
    event DraftWorkRejected(
        uint256 indexed campaignId,
        uint256 indexed draftWorkId
    );
    event ContentPublished(
        uint256 indexed campaignId,
        uint256 indexed publishWorkId
    );
    event AnalyticShared(
        uint256 indexed campaignId,
        uint256 indexed contentAnalyticId
    );

    // Modifiers
    modifier onlyRegisteredUser() {
        require(userExists[msg.sender], "User not registered");
        _;
    }

    modifier onlyUnregisteredUser() {
        require(!userExists[msg.sender], "User already registered");
        _;
    }

    modifier onlyAdmin() {
        require(
            users[msg.sender].role == UserRole.Admin,
            "Only Admin can call this function!"
        );
        _;
    }

    modifier onlyCampaigner() {
        require(
            users[msg.sender].role == UserRole.Campaigner,
            "Only Campaigner can call this function!"
        );
        _;
    }

    modifier onlyKOL() {
        require(
            users[msg.sender].role == UserRole.KOL,
            "Only KOL can call this function!"
        );
        _;
    }

    modifier existedCampaign(uint256 _campaignId) {
        require(
            campaignExists[_campaignId], 
            "Campaign's not exist!"
        );
        _;
    }

    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(msg.sender == campaigns[_campaignId].createdBy,
        "Only Campaign Creator can call this function!"
    );
        _;
    }

    modifier onlyCampaignKOLWorker(uint256 _campaignId) {
        require(msg.sender == campaigns[_campaignId].kolWorker,
        "Only Campaign Creator can call this function!"
    );
        _;
    }

    modifier ApplicationExist(uint256 _applicationId) {
        require(applicationExists[_applicationId], "Application's not exist!");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function getUser() public view onlyRegisteredUser returns (User memory) {
        return users[msg.sender];
    }

    function registerUser(
        string memory _name,
        string memory _summary,
        UserRole _role
    ) public onlyUnregisteredUser {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_summary).length > 0, "Summary cannot be empty");

        users[msg.sender].name = _name;
        users[msg.sender].summary = _summary;
        users[msg.sender].role = _role;

        userExists[msg.sender] = true;

        emit UserRegistered(msg.sender, uint8(_role), block.timestamp);
    }

    function editUser(
        string memory _name,
        string memory _summary,
        UserRole _role
    ) public onlyRegisteredUser {
        users[msg.sender].name = _name;
        users[msg.sender].summary = _summary;
        users[msg.sender].role = _role;

        emit UserUpdated(msg.sender, block.timestamp);
    }
    
    function getAllCampaignIds() public view returns (uint256[] memory) {
        return campaignList;
    }

    function getCampaign(
        uint256 _campaignId
    ) public view existedCampaign(_campaignId) returns (
        string memory title,
        string memory description,
        string memory brief,
        string memory goal,
        uint256 startDate,
        uint256 endDate,
        campaignPlatform[] memory targetPlatform,
        campaignContentType[] memory contentTypes,
        string memory targetAudience,
        string memory guideline,
        uint256 reward,
        CampaignStatus status
    ) {
        Campaign storage campaign = campaigns[_campaignId];

        return (
            campaign.title,
            campaign.description,
            campaign.brief,
            campaign.goal,
            campaign.startDate,
            campaign.endDate,
            campaign.targetPlatform,
            campaign.contentTypes,
            campaign.targetAudience,
            campaign.guideline,
            campaign.reward,
            campaign.status
        );
    }

    function createCampaign(
        string memory _title,
        string memory _description,
        string memory _brief,
        string memory _goal,
        uint256 _startDate,
        uint256 _endDate,
        campaignPlatform _targetPlatform,
        campaignContentType _contentTypes,
        string memory _targetAudience,
        string memory _guideline
    ) public payable nonReentrant onlyCampaigner returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_title).length <= 200, "Title too long");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(msg.value > 0, "Reward must be positive");
        
        uint256 campaignId = campaignIdCounter++;

        campaigns[campaignId].title = _title;
        campaigns[campaignId].description = _description;
        campaigns[campaignId].brief = _brief;
        campaigns[campaignId].goal = _goal;
        campaigns[campaignId].startDate = _startDate;
        campaigns[campaignId].endDate = _endDate;
        campaigns[campaignId].targetPlatform.push(_targetPlatform);
        campaigns[campaignId].contentTypes.push(_contentTypes);
        campaigns[campaignId].targetAudience = _targetAudience;
        campaigns[campaignId].guideline = _guideline;
        campaigns[campaignId].reward = msg.value;
        campaigns[campaignId].status = CampaignStatus.Published;
        campaigns[campaignId].createdAt = block.timestamp;
        campaigns[campaignId].createdBy = msg.sender;

        campaignList.push(campaignId);

        campaignExists[campaignId] = true;

        campaignEscrow[campaignId] = msg.value;

        campaignPayments[campaignId].campaignId = campaignId;
        campaignPayments[campaignId].amount = msg.value;
        campaignPayments[campaignId].status = PaymentStatus.Escrowed;
        campaignPayments[campaignId].escrowedAt = block.timestamp;

        emit CampaignCreated(
            campaignId,
            msg.sender,
            campaignEscrow[campaignId]
        );

        return campaignId;
    }

    function editCampaign(
        uint256 _campaignId,
        string memory _title,
        string memory _description
    ) public existedCampaign(_campaignId) onlyCampaignCreator(_campaignId) returns (uint256) {
        require(
            campaigns[_campaignId].status == CampaignStatus.New,
            "Can only edit draft campaigns"
        );

        campaigns[_campaignId].title = _title;
        campaigns[_campaignId].description = _description;
        campaigns[_campaignId].updatedBy = msg.sender;
        campaigns[_campaignId].updatedAt = block.timestamp;

        emit CampaignUpdated(
            _campaignId,
            msg.sender,
            campaignEscrow[_campaignId]
        );

        return _campaignId;
    }

    // Can be developed or not
    // function publishCampaign(
    //     uint256 _campaignId
    // ) public existedCampaign(_campaignId) onlyCampaignCreator(_campaignId) returns (uint256) {        
    //     require(
    //         campaigns[_campaignId].status == CampaignStatus.New,
    //         "Campaign already published"
    //     );
        
    //     campaigns[_campaignId].status = CampaignStatus.Published;

    //     emit CampaignPublished(
    //         _campaignId,
    //         msg.sender,
    //         campaignEscrow[_campaignId]
    //     );

    //     return _campaignId;
    // }


    function cancelCampaign(uint256 _campaignId) 
        external 
        existedCampaign(_campaignId)
        onlyCampaignCreator(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        
        // Can only cancel before KOL starts work
        require(
            campaign.status == CampaignStatus.New || 
            campaign.status == CampaignStatus.Published,
            "Cannot cancel at this stage"
        );
        
        campaign.status = CampaignStatus.Cancelled;
        
        emit CampaignCancelled(_campaignId, msg.sender, block.timestamp);
    }

    function submitApplication(
        uint256 _campaignId,
        string memory _title,
        string memory _proposal
    ) public existedCampaign(_campaignId) onlyKOL returns (uint256) {        
        require(campaigns[_campaignId].status == CampaignStatus.Published, "Campaign's not published!");

        uint256 applicationId = applicationIdCounter++;

        applications[applicationId].campaignId = _campaignId;
        applications[applicationId].applicantAddress = msg.sender;
        applications[applicationId].title = _title;
        applications[applicationId].proposal = _proposal;
        applications[applicationId].status = ApplicationStatus.Submitted;

        applicationExists[applicationId] = true;

        campaignApplicants[_campaignId].push(applicationId);
        
        isApplicantInCampaign[_campaignId][applicationId] = true;

        emit ApplicationSubmitted(
            _campaignId,
            applicationId,
            msg.sender
        );

        return applicationId;
    }

    function getAllApplication(
        uint256 _campaignId
    ) public view existedCampaign(_campaignId) returns (uint256[] memory) {
        return campaignApplicants[_campaignId];
    }

    function getApplication(
        uint256 _applicationId
    ) public view ApplicationExist(_applicationId) returns (Application memory) {
        return applications[_applicationId];
    }

    function cancelApplication(
        uint256 _campaignId,
        uint256 _applicationId
    ) public existedCampaign(_campaignId) onlyKOL ApplicationExist(_applicationId) {
        require(
            isApplicantInCampaign[_campaignId][_applicationId], 
            "Application not registered in campaign!"
        );
        require(
            applications[_applicationId].applicantAddress == msg.sender,
            "Not your application"
        );
        
        Application storage applicationData = applications[_applicationId];

        applicationData.status = ApplicationStatus.Cancelled;

        emit ApplicationCancelled(
            _campaignId,
            _applicationId,
            msg.sender
        );
    }

    function approveApplication(
        uint256 _campaignId,
        uint256 _applicationId
    ) public existedCampaign(_campaignId) onlyCampaignCreator(_campaignId) ApplicationExist(_applicationId)  returns (bool) {
        Campaign storage campaignData = campaigns[_campaignId];
        Application storage applicationData = applications[_applicationId];

        require(
            isApplicantInCampaign[_campaignId][_applicationId], 
            "Application not registered in campaign!"
        );
        require(
            campaigns[_campaignId].status == CampaignStatus.Published, 
            "Campaign's not published!"
        );

        campaignData.status = CampaignStatus.InProgress;
        campaignData.kolWorker = applicationData.applicantAddress;

        applicationData.status = ApplicationStatus.Approved;

        emit ApplicationApproved(
            _campaignId,
            _applicationId
        );

        return true;
    }

    function rejectApplication(
        uint256 _campaignId,
        uint256 _applicationId
    ) public existedCampaign(_campaignId) onlyCampaignCreator(_campaignId) ApplicationExist(_applicationId)  returns (bool) {
        require(campaigns[_campaignId].status == CampaignStatus.Published, "Campaign's not published!");

        Application storage applicationData = applications[_applicationId];
        
        applicationData.status = ApplicationStatus.Rejected;

        emit ApplicationRejected(
            _campaignId,
            _applicationId
        );

        return true;
    }

    function submitDraftWork(
        uint256 _campaignId,
        string memory _data
    ) public existedCampaign(_campaignId) onlyKOL onlyCampaignKOLWorker(_campaignId) {
        require(bytes(_data).length > 0, "Data cannot be empty"); 

        uint256 draftWorkId = draftWorkIdCounter++;

        draftWorks[draftWorkId].campaignId = _campaignId;
        draftWorks[draftWorkId].kolAddress = msg.sender;
        draftWorks[draftWorkId].data = _data;
        draftWorks[draftWorkId].status = DraftWorkStatus.Submitted;

        draftWorkExists[draftWorkId] = true;

        emit DraftWorkSubmitted(
            _campaignId,
            draftWorkId
        );
    }

    function getDraftWork(
        uint256 _draftWorkId
    ) public view returns (DraftWork memory) {
        require(draftWorkExists[_draftWorkId], "Draft work does not exist");

        return draftWorks[_draftWorkId];
    }

    function approveDraftWork(
        uint256 _campaignId,
        uint256 _draftWorkId
    ) public onlyCampaigner onlyCampaignCreator(_campaignId) {
        DraftWork storage draftWork = draftWorks[_draftWorkId];

        draftWorks[_draftWorkId].status = DraftWorkStatus.Approved;
        
        campaigns[draftWork.campaignId].status = CampaignStatus.ContentDrafted;
        
        emit DraftWorkApproved(
            _campaignId,
            _draftWorkId
        );
    }

    function rejectDraftWork(
        uint256 _campaignId,
        uint256 _draftWorkId
    ) public onlyCampaigner onlyCampaignCreator(_campaignId) {
        draftWorks[_draftWorkId].status = DraftWorkStatus.Rejected;

        emit DraftWorkRejected(
            _campaignId,
            _draftWorkId
        );
    }

    function publishContent (
        uint256 _campaignId,
        string memory _data
    ) public existedCampaign(_campaignId) onlyKOL onlyCampaignKOLWorker(_campaignId) {
        require(campaigns[_campaignId].status == CampaignStatus.ContentDrafted, "Campaign doesn't have any approved drafted content yet!");

        uint256 publishedContentId = publishedContentIdCounter++;

        publishedContents[publishedContentId].campaignId = _campaignId;
        publishedContents[publishedContentId].data = _data;

        publishedContentExists[publishedContentId] = true;

        campaigns[_campaignId].status = CampaignStatus.ContentPublished;

        emit ContentPublished(_campaignId, publishedContentId);
    }

    function shareAnalytic (
        uint256 _campaignId,
        string memory _data
    ) public existedCampaign(_campaignId) onlyKOL onlyCampaignKOLWorker(_campaignId) {
        require(campaigns[_campaignId].status == CampaignStatus.ContentPublished, "Campaign doesn't have any published content yet!");

        uint256 contentAnalyticId = contentAnalyticIdCounter++;

        contentAnalytics[contentAnalyticId].campaignId = _campaignId;
        contentAnalytics[contentAnalyticId].data = _data;

        contentAnalyticExists[contentAnalyticId] = true; 

        campaigns[_campaignId].status = CampaignStatus.AnalyticShared;

        emit AnalyticShared(_campaignId, contentAnalyticId);
    }

    function completeCampaign(
        uint256 _campaignId
    ) public existedCampaign(_campaignId) onlyCampaignCreator(_campaignId) {
        require(campaigns[_campaignId].status == CampaignStatus.AnalyticShared, "Campaign doesn't have any analytic yet!");

        campaigns[_campaignId].status = CampaignStatus.Done;

        emit CampaignCompleted(_campaignId);
    }

    function withdrawCampaign(
        uint256 _campaignId
    ) public nonReentrant existedCampaign(_campaignId) onlyKOL onlyCampaignKOLWorker(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        Payment storage campaignPayment = campaignPayments[_campaignId];
        uint256 amount = campaignEscrow[_campaignId];
                
        require(campaign.status == CampaignStatus.Done, "Campaign's not done yet!");
        require(campaignPayment.status == PaymentStatus.Escrowed, "Reward already withdrawn!");
        require(campaign.reward > 0, "No funds available");
        require(amount > 0, "No funds available");
        
        campaignPayment.status = PaymentStatus.Released;
        campaignPayment.releasedAt = block.timestamp;
        campaignEscrow[_campaignId] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdraw failed!");

        emit RewardWithdrawn(
            _campaignId,
            msg.sender,
            amount,
            block.timestamp
        );
    }

    function refundCampaign(
        uint256 _campaignId
    ) public nonReentrant existedCampaign(_campaignId) onlyCampaigner onlyCampaignCreator(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        Payment storage campaignPayment = campaignPayments[_campaignId];
        uint256 amount = campaignEscrow[_campaignId];
                
        require(campaign.status == CampaignStatus.Cancelled, "Campaign's not cancelled!");
        require(campaignPayment.status == PaymentStatus.Escrowed, "Reward already withdrawn!");
        require(amount > 0, "No funds available");
        
        campaignPayment.status = PaymentStatus.Refunded;
        campaignPayment.refundedAt = block.timestamp;
        campaignEscrow[_campaignId] = 0;

        (bool success, ) = campaign.createdBy.call{value: amount}("");
        require(success, "Withdraw failed!");

        emit RewardRefunded(
            _campaignId,
            campaign.createdBy,
            amount,
            block.timestamp
        );
    }
}

