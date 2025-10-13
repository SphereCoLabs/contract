// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FreelancePlatform {
    // Contract owner (represents the platform/AI verifier)
    address public owner;
    
    // Fee percentage taken by the platform (in basis points, e.g., 250 = 2.5%)
    uint256 public platformFeeBps = 250;
    
    // Percentage of payment released after AI verification (in basis points, e.g., 7000 = 70%)
    uint256 public aiVerificationReleaseBps = 7000;
    
    // Job status enum
    enum JobStatus { 
        Open,       // Job is open for applications
        Assigned,   // Job has been assigned to a freelancer
        Submitted,  // Work has been submitted by the freelancer
        AIVerified, // Work has been verified by AI
        Completed,  // Work has been approved by job poster and payment released
        Cancelled   // Job has been cancelled
    }
    
    // Application status enum
    enum ApplicationStatus {
        Pending,    // Application is pending
        Accepted,   // Application has been accepted
        Rejected    // Application has been rejected
    }
    
    // Job struct
    struct Job {
        uint256 id;
        address poster;
        string title;
        string description;
        uint256 reward;
        uint256 deadline;
        JobStatus status;
        address assignedFreelancer;
        bool partialPaymentReleased;
        uint256 timestamp;
    }
    
    // Application struct
    struct Application {
        uint256 id;
        uint256 jobId;
        address freelancer;
        string proposal;
        ApplicationStatus status;
        uint256 timestamp;
    }
    
    // Submission struct
    struct Submission {
        uint256 id;
        uint256 jobId;
        address freelancer;
        string deliverable;
        bool aiVerified;
        bool posterApproved;
        uint256 timestamp;
    }
    
    // Counters for generating unique IDs
    uint256 private jobIdCounter;
    uint256 private applicationIdCounter;
    uint256 private submissionIdCounter;
    
    // Mappings
    mapping(uint256 => Job) public jobs;
    mapping(uint256 => Application) public applications;
    mapping(uint256 => Submission) public submissions;
    mapping(uint256 => uint256[]) public jobToApplications;
    mapping(uint256 => uint256) public jobToSubmission;
    
    // Events
    event JobCreated(uint256 indexed jobId, address indexed poster, uint256 reward);
    event ApplicationSubmitted(uint256 indexed applicationId, uint256 indexed jobId, address indexed freelancer);
    event ApplicationAccepted(uint256 indexed applicationId, uint256 indexed jobId, address indexed freelancer);
    event WorkSubmitted(uint256 indexed submissionId, uint256 indexed jobId, address indexed freelancer);
    event WorkVerifiedByAI(uint256 indexed submissionId, uint256 indexed jobId, address indexed freelancer);
    event PartialPaymentReleased(uint256 indexed jobId, address indexed freelancer, uint256 amount);
    event WorkApproved(uint256 indexed submissionId, uint256 indexed jobId, address indexed freelancer, uint256 reward);
    event JobCancelled(uint256 indexed jobId);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner/AI can call this function");
        _;
    }
    
    modifier onlyJobPoster(uint256 _jobId) {
        require(msg.sender == jobs[_jobId].poster, "Only the job poster can call this function");
        _;
    }
    
    modifier onlyAssignedFreelancer(uint256 _jobId) {
        require(msg.sender == jobs[_jobId].assignedFreelancer, "Only the assigned freelancer can call this function");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
    }
    
    // Function to create a job (for job posters)
    function createJob(string memory _title, string memory _description, uint256 _deadline) external payable {
        require(msg.value > 0, "Reward must be greater than 0");
        
        uint256 jobId = jobIdCounter++;
        
        jobs[jobId] = Job({
            id: jobId,
            poster: msg.sender,
            title: _title,
            description: _description,
            reward: msg.value,
            deadline: _deadline,
            status: JobStatus.Open,
            assignedFreelancer: address(0),
            partialPaymentReleased: false,
            timestamp: block.timestamp
        });
        
        emit JobCreated(jobId, msg.sender, msg.value);
    }
    
    // Function to apply for a job (for freelancers)
    function applyForJob(uint256 _jobId, string memory _proposal) external {
        require(jobs[_jobId].status == JobStatus.Open, "Job is not open for applications");
        require(block.timestamp < jobs[_jobId].deadline, "Job application deadline has passed");
        
        uint256 applicationId = applicationIdCounter++;
        
        applications[applicationId] = Application({
            id: applicationId,
            jobId: _jobId,
            freelancer: msg.sender,
            proposal: _proposal,
            status: ApplicationStatus.Pending,
            timestamp: block.timestamp
        });
        
        jobToApplications[_jobId].push(applicationId);
        
        emit ApplicationSubmitted(applicationId, _jobId, msg.sender);
    }
    
    // Function for job poster to accept an application
    function acceptApplication(uint256 _applicationId) external {
        Application storage application = applications[_applicationId];
        uint256 jobId = application.jobId;
        
        require(msg.sender == jobs[jobId].poster, "Only the job poster can accept applications");
        require(jobs[jobId].status == JobStatus.Open, "Job is not open");
        require(application.status == ApplicationStatus.Pending, "Application is not pending");
        
        application.status = ApplicationStatus.Accepted;
        jobs[jobId].status = JobStatus.Assigned;
        jobs[jobId].assignedFreelancer = application.freelancer;
        
        // Reject all other applications for this job
        uint256[] memory otherApplications = jobToApplications[jobId];
        for (uint256 i = 0; i < otherApplications.length; i++) {
            if (otherApplications[i] != _applicationId) {
                applications[otherApplications[i]].status = ApplicationStatus.Rejected;
            }
        }
        
        emit ApplicationAccepted(_applicationId, jobId, application.freelancer);
    }
    
    // Function for freelancer to submit work
    function submitWork(uint256 _jobId, string memory _deliverable) external onlyAssignedFreelancer(_jobId) {
        require(jobs[_jobId].status == JobStatus.Assigned, "Job is not assigned to you");
        
        uint256 submissionId = submissionIdCounter++;
        
        submissions[submissionId] = Submission({
            id: submissionId,
            jobId: _jobId,
            freelancer: msg.sender,
            deliverable: _deliverable,
            aiVerified: false,
            posterApproved: false,
            timestamp: block.timestamp
        });
        
        jobToSubmission[_jobId] = submissionId;
        jobs[_jobId].status = JobStatus.Submitted;
        
        emit WorkSubmitted(submissionId, _jobId, msg.sender);
    }
    
    // Function for AI to verify work and release partial payment
    function verifyWorkByAI(uint256 _submissionId, bool _verified) external onlyOwner {
        Submission storage submission = submissions[_submissionId];
        uint256 jobId = submission.jobId;
        
        require(jobs[jobId].status == JobStatus.Submitted, "Work has not been submitted");
        
        submission.aiVerified = _verified;
        
        if (_verified) {
            jobs[jobId].status = JobStatus.AIVerified;
            
            // Calculate partial payment amount
            uint256 partialPaymentAmount = (jobs[jobId].reward * aiVerificationReleaseBps) / 10000;
            
            // Release partial payment to freelancer
            if (partialPaymentAmount > 0 && !jobs[jobId].partialPaymentReleased) {
                jobs[jobId].partialPaymentReleased = true;
                payable(submission.freelancer).transfer(partialPaymentAmount);
                emit PartialPaymentReleased(jobId, submission.freelancer, partialPaymentAmount);
            }
            
            emit WorkVerifiedByAI(_submissionId, jobId, submission.freelancer);
        }
    }
    
    // Function for job poster to approve work and release remaining payment
    function approveWork(uint256 _submissionId) external {
        Submission storage submission = submissions[_submissionId];
        uint256 jobId = submission.jobId;
        
        require(msg.sender == jobs[jobId].poster, "Only the job poster can approve work");
        require(jobs[jobId].status == JobStatus.AIVerified, "Work has not been verified by AI");
        require(submission.aiVerified, "Work has not been verified by AI");
        
        submission.posterApproved = true;
        jobs[jobId].status = JobStatus.Completed;
        
        // Calculate remaining payment
        uint256 totalPayment = jobs[jobId].reward;
        uint256 platformFee = (totalPayment * platformFeeBps) / 10000;
        uint256 alreadyPaid = jobs[jobId].partialPaymentReleased ? 
                             (totalPayment * aiVerificationReleaseBps) / 10000 : 0;
        uint256 remainingPayment = totalPayment - alreadyPaid - platformFee;
        
        // Transfer remaining payment and platform fee
        if (remainingPayment > 0) {
            payable(submission.freelancer).transfer(remainingPayment);
        }
        payable(owner).transfer(platformFee);
        
        emit WorkApproved(_submissionId, jobId, submission.freelancer, totalPayment - platformFee);
    }
    
    // Function for job poster to cancel a job (only if no freelancer is assigned yet)
    function cancelJob(uint256 _jobId) external onlyJobPoster(_jobId) {
        require(jobs[_jobId].status == JobStatus.Open, "Job cannot be cancelled at its current state");
        
        jobs[_jobId].status = JobStatus.Cancelled;
        
        // Refund the reward to the job poster
        payable(msg.sender).transfer(jobs[_jobId].reward);
        
        emit JobCancelled(_jobId);
    }
    
    // Function to get all applications for a job
    function getJobApplications(uint256 _jobId) external view returns (uint256[] memory) {
        return jobToApplications[_jobId];
    }
    
    // Function to get job details
    function getJobDetails(uint256 _jobId) external view returns (
        address poster,
        string memory title,
        string memory description,
        uint256 reward,
        uint256 deadline,
        JobStatus status,
        address assignedFreelancer
    ) {
        Job storage job = jobs[_jobId];
        return (
            job.poster,
            job.title,
            job.description,
            job.reward,
            job.deadline,
            job.status,
            job.assignedFreelancer
        );
    }
    
    // Function to get submission details
    function getSubmissionDetails(uint256 _submissionId) external view returns (
        uint256 jobId,
        address freelancer,
        string memory deliverable,
        bool aiVerified,
        bool posterApproved,
        uint256 timestamp
    ) {
        Submission storage submission = submissions[_submissionId];
        return (
            submission.jobId,
            submission.freelancer,
            submission.deliverable,
            submission.aiVerified,
            submission.posterApproved,
            submission.timestamp
        );
    }
    
    // Function to update platform fee (only owner)
    function updatePlatformFee(uint256 _newFeeBps) external onlyOwner {
        require(_newFeeBps <= 1000, "Fee cannot exceed 10%");
        platformFeeBps = _newFeeBps;
    }
    
    // Function to update AI verification release percentage (only owner)
    function updateAIVerificationReleaseBps(uint256 _newReleaseBps) external onlyOwner {
        require(_newReleaseBps <= 8000, "Release percentage cannot exceed 80%");
        aiVerificationReleaseBps = _newReleaseBps;
    }
}
