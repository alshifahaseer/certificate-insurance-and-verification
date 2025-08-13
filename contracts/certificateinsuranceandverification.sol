// SPDX-License-Identifier: 
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title Certificate Insurance and Verification System
 * @dev Smart contract for managing digital certificates with insurance capabilities
 */
contract Project is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
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

    event CertificateIssued(uint256 indexed certificateId, string name, address indexed holder, string issuer);
    event CertificateVerified(uint256 indexed certificateId, address indexed verifier);
    event InsurancePurchased(uint256 indexed certificateId, address indexed holder, uint256 premiumAmount, uint256 coverageAmount);
    event InsuranceClaimed(uint256 indexed certificateId, address indexed holder, uint256 claimAmount);

    modifier validCertificate(uint256 _certificateId) {
        require(_certificateId > 0 && _certificateId <= _certificateIds.current(), "Invalid certificate ID");
        require(certificates[_certificateId].isValid, "Certificate is not valid");
        _;
    }

    modifier onlyCertificateHolder(uint256 _certificateId) {
        require(certificates[_certificateId].holder == msg.sender, "Not the certificate holder");
        _;
    }

    function issueCertificate(
        string memory _name,
        string memory _issuer,
        address _holder,
        uint256 _expiryDays,
        string memory _ipfsHash
    ) external onlyOwner returns (uint256) {
        require(!usedHashes[_ipfsHash], "Certificate already issued with this IPFS hash");

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

        if (msg.value > requiredPremium) {
            payable(msg.sender).transfer(msg.value - requiredPremium);
        }

        emit InsurancePurchased(_certificateId, msg.sender, requiredPremium, _coverageAmount);
    }

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

