// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters
/**
 * @title Certificate Insurance and Verification System
 * @dev Smart contract for managing digital certificates with insurance capabilities
 */
contract Project is Ownable, ReentrancyGu
    constructor() Ownable(msg.sender)
        // Initialize the contract with the deployer as the initial owner
    Counters.Counter private _certificateIds;
constructor() Ownable(msg.sender)

    Counters.Counter private _certificateIds;
    
    struct Certificate {
        uint256 id;
        string name;
        string issuer;
        address holder;
        uint256 issuedDate;
        uint256 expiryDate;
        string ipfsHash;
        bool isValid;
        bool isInsured;
        uint256 insuranceAmount;
        uint256 insurancePremium;
        bool claimProcessed;
    }
    
    struct InsurancePolicy {
        uint256 certificateId;
        uint256 premiumAmount;
        uint256 coverageAmount;
        uint256 policyStart;
        uint256 policyEnd;
        bool isActive;
    }
    
    mapping(uint256 => Certificate) public certificates;
    mapping(uint256 => InsurancePolicy) public insurancePolicies;
    mapping(address => uint256[]) public holderCertificates;
    mapping(string => bool) public usedHashes;
    
    uint256 public constant INSURANCE_RATE = 5; // 5% of certificate value
    uint256 public insurancePool;
    
    event CertificateIssued(
        uint256 indexed certificateId,
        string name,
        address indexed holder,
        string issuer
    );
    
    event CertificateVerified(
        uint256 indexed certificateId,
        address indexed verifier
    );
    
    event InsurancePurchased(
        uint256 indexed certificateId,
        address indexed holder,
        uint256 premiumAmount,
        uint256 coverageAmount
    );
    
    event InsuranceClaimed(
        uint256 indexed certificateId,
        address indexed holder,
        uint256 claimAmount
    );
    
    modifier validCertificate(uint256 _certificateId) {
        require(_certificateId > 0 && _certificateId <= _certificateIds.current(), "Invalid certificate ID");
        require(certificates[_certificateId].isValid, "Certificate is not valid")
    
    modifier onlyCertificateHolder(uint256 _certificateId) {
        require(certificates[_certificateId].holder == msg.sender, "Not the certificate holder");
        _;
    }
    
    /**
     * @dev Issue a new certificate
     * @param _name Name of the certificate
     * @param _issuer Issuer organization
     * @param _holder Address of the certificate holder
     * @param _expiryDays Number of days until expiry
     * @param _ipfsHash IPFS hash of the certificate document
     */
 
        
        _certificateIds.increment();
        uint256 newCertificateId = _certificateIds.current();
        
        uint256 expiryDate = block.timestamp + (_expiryDays * 1 days);
        
        certificates[newCertificateId] = Certificate({
            id: newCertificateId,
            name: _name,
            issuer: _issuer,
            holder: _holder,
            issuedDate: block.timestamp,
            expiryDate: expiryDate,
            ipfsHash: _ipfsHash,
            isValid: true,
            isInsured: false,
            insuranceAmount: 0,
            insurancePremium: 0,
            claimProcessed: false
        });
        
        holderCertificates[_holder].push(newCertificateId);
        usedHashes[_ipfsHash] = true;
        
        emit CertificateIssued(newCertificateId, _name, _holder, _issuer);
        
        return newCertificateId;
    }
    
    /**
     * @dev Verify a certificate's authenticity and validity
     * @param _certificateId ID of the certificate to verify
     * @return isValid True if certificate is valid and not expired
     * @return certificate Certificate details
     */
    function verifyCertificate(uint256 _certificateId) 
        external 
        view 
        returns (bool isValid, Certificate memory certificate) 
    {
        require(_certificateId > 0 && _certificateId <= _certificateIds.current(), "Invalid certificate ID");
        
        Certificate memory cert = certificates[_certificateId];
        bool valid = cert.isValid && block.timestamp <= cert.expiryDate;
        
        return (valid, cert);
    }
    
    /**
     * @dev Purchase insurance for a certificate
     * @param _certificateId ID of the certificate to insure
     * @param _coverageAmount Amount of coverage desired
     */
    function purchaseInsurance(uint256 _certificateId, uint256 _coverageAmount) 
        external 
        payable 
        validCertificate(_certificateId)
        onlyCertificateHolder(_certificateId)
        nonReentrant 
    {
        require(_coverageAmount > 0, "Coverage amount must be positive");
        require(!certificates[_certificateId].isInsured, "Certificate already insured");
        require(block.timestamp <= certificates[_certificateId].expiryDate, "Certificate expired");
        
        uint256 requiredPremium = (_coverageAmount * INSURANCE_RATE) / 100;
        require(msg.value >= requiredPremium, "Insufficient premium payment");
        
        certificates[_certificateId].isInsured = true;
        certificates[_certificateId].insuranceAmount = _coverageAmount;
        certificates[_certificateId].insurancePremium = requiredPremium;
        
        insurancePolicies[_certificateId] = InsurancePolicy({
            certificateId: _certificateId,
            premiumAmount: requiredPremium,
            coverageAmount: _coverageAmount,
            policyStart: block.timestamp,
            policyEnd: certificates[_certificateId].expiryDate,
            isActive: true
        });
        
        insurancePool += requiredPremium;
        
        // Refund excess payment
        if (msg.value > requiredPremium) {
            payable(msg.sender).transfer(msg.value - requiredPremium);
        }
        
        emit InsurancePurchased(_certificateId, msg.sender, requiredPremium, _coverageAmount);
    }
    
    /**
     * @dev Claim insurance for a revoked or invalid certificate
     * @param _certificateId ID of the certificate to claim insurance for
     */
    function claimInsurance(uint256 _certificateId) 
        external 
        onlyCertificateHolder(_certificateId)
        nonReentrant 
    {
        Certificate storage cert = certificates[_certificateId];
        InsurancePolicy storage policy = insurancePolicies[_certificateId];
        
        require(cert.isInsured, "Certificate is not insured");
        require(policy.isActive, "Insurance policy is not active");
        require(!cert.claimProcessed, "Insurance claim already processed");
        require(!cert.isValid || block.timestamp > cert.expiryDate, "Certificate is still valid");
        require(insurancePool >= cert.insuranceAmount, "Insufficient insurance pool");
        
        cert.claimProcessed = true;
        policy.isActive = false;
        insurancePool -= cert.insuranceAmount;
        
        payable(msg.sender).transfer(cert.insuranceAmount);
        
        emit InsuranceClaimed(_certificateId, msg.sender, cert.insuranceAmount);
    }
    
    // Additional utility functions
    function getTotalCertificates() external view returns (uint256) {
        return _certificateIds.current();
    }
    
    function getHolderCertificates(address _holder) external view returns (uint256[] memory) {
        return holderCertificates[_holder];
    }
    
    function getInsurancePool() external view returns (uint256) {
        return insurancePool;
    }
    
    function revokeCertificate(uint256 _certificateId) external onlyOwner validCertificate(_certificateId) {
        certificates[_certificateId].isValid = false;
    }
    
    function withdrawInsurancePool() external onlyOwner {
        require(insurancePool > 0, "No funds to withdraw");
        uint256 amount = insurancePool;
        insurancePool = 0;
        payable(owner()).transfer(amount);
    }
    
    receive() external payable {
        insurancePool += msg.value;
    }
}
