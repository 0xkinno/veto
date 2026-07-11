// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title VetoAttestation
 * @author VETO
 * @notice The on-chain commitment log for VETO verdicts. Every ruling the
 *         engine makes can be committed here so it is independently
 *         verifiable against the chain. VETO never asks to be believed;
 *         this contract is the receipt.
 *
 * @dev Designed to deploy once and never be replaced. It is deliberately
 *      NOT a proxy — the surface is small and legible — but it carries
 *      every hook VETO's roadmap needs:
 *
 *        - the verdict itself is stored (ALLOW / WARN / VETO), not just a hash
 *        - per-agent verdict history for on-chain reputation / counterparty reads
 *        - batch attestation for gas-efficient high volume
 *        - revoke / supersede that preserves history (forensics trail intact)
 *        - a payment reference per verdict so x402 settlement can bind on-chain
 *        - a free-form bytes metadata slot per verdict for data not yet designed
 *        - multi-attester authorisation with revocation
 *        - pausable kill switch and two-step ownership transfer
 */
contract VetoAttestation {
    // ----------------------------------------------------------------- types

    enum Verdict {
        NONE, // 0 — never attested
        ALLOW, // 1
        WARN, // 2
        VETO // 3
    }

    struct Attestation {
        bytes32 verdictHash; // keccak of the canonical verdict object
        bytes32 evidenceHash; // keccak of the evidence bundle
        bytes32 policyId; // policy profile applied
        address agent; // the agent/wallet the verdict was rendered for
        address attester; // engine signer that submitted it
        Verdict verdict; // the actual ruling, readable on-chain
        uint64 timestamp; // block time of the write
        bool revoked; // superseded / corrected, history preserved
        bytes32 supersededBy; // evidenceHash of the correcting attestation
        bytes32 paymentRef; // x402 settlement reference (0 if none)
    }

    // ------------------------------------------------------------- storage

    /// @dev evidenceHash => attestation. One commitment per evidence bundle.
    mapping(bytes32 => Attestation) public attestations;

    /// @dev agent => list of evidence hashes rendered for it (reputation feed).
    mapping(address => bytes32[]) private _agentHistory;

    /// @dev evidenceHash => free-form metadata for data not yet designed.
    mapping(bytes32 => bytes) public metadata;

    /// @dev authorised engine signers.
    mapping(address => bool) public attesters;

    address public owner;
    address public pendingOwner;
    bool public paused;
    uint256 public total;

    // -------------------------------------------------------------- events

    event Attested(
        bytes32 indexed evidenceHash,
        bytes32 indexed verdictHash,
        address indexed agent,
        Verdict verdict,
        bytes32 policyId,
        address attester,
        uint64 timestamp
    );
    event Revoked(bytes32 indexed evidenceHash, bytes32 supersededBy);
    event MetadataSet(bytes32 indexed evidenceHash);
    event PaymentBound(bytes32 indexed evidenceHash, bytes32 paymentRef);
    event AttesterSet(address indexed attester, bool allowed);
    event Paused(bool paused);
    event OwnershipTransferStarted(address indexed from, address indexed to);
    event OwnershipTransferred(address indexed from, address indexed to);

    // ------------------------------------------------------------ modifiers

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyAttester() {
        require(attesters[msg.sender], "not attester");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "paused");
        _;
    }

    // ---------------------------------------------------------- constructor

    constructor() {
        owner = msg.sender;
        attesters[msg.sender] = true;
        emit AttesterSet(msg.sender, true);
    }

    // -------------------------------------------------------- attestation

    /**
     * @notice Commit a verdict to the chain.
     * @param verdictHash  keccak of the canonical verdict object
     * @param evidenceHash keccak of the evidence bundle (the unique key)
     * @param policyId     policy profile applied
     * @param agent        the agent/wallet the verdict was rendered for
     * @param verdict      the ruling (ALLOW / WARN / VETO)
     * @param paymentRef   x402 settlement reference, or bytes32(0) if none
     */
    function attest(
        bytes32 verdictHash,
        bytes32 evidenceHash,
        bytes32 policyId,
        address agent,
        Verdict verdict,
        bytes32 paymentRef
    ) public onlyAttester whenNotPaused {
        require(evidenceHash != bytes32(0), "empty evidence");
        require(verdict != Verdict.NONE, "invalid verdict");
        require(attestations[evidenceHash].timestamp == 0, "already attested");

        attestations[evidenceHash] = Attestation({
            verdictHash: verdictHash,
            evidenceHash: evidenceHash,
            policyId: policyId,
            agent: agent,
            attester: msg.sender,
            verdict: verdict,
            timestamp: uint64(block.timestamp),
            revoked: false,
            supersededBy: bytes32(0),
            paymentRef: paymentRef
        });

        if (agent != address(0)) _agentHistory[agent].push(evidenceHash);

        unchecked {
            total++;
        }

        emit Attested(
            evidenceHash,
            verdictHash,
            agent,
            verdict,
            policyId,
            msg.sender,
            uint64(block.timestamp)
        );

        if (paymentRef != bytes32(0)) {
            emit PaymentBound(evidenceHash, paymentRef);
        }
    }

    /**
     * @notice Commit many verdicts in a single transaction. Arrays must be
     *         the same length. Any duplicate/empty entry reverts the batch.
     */
    function attestBatch(
        bytes32[] calldata verdictHashes,
        bytes32[] calldata evidenceHashes,
        bytes32[] calldata policyIds,
        address[] calldata agents,
        Verdict[] calldata verdicts,
        bytes32[] calldata paymentRefs
    ) external onlyAttester whenNotPaused {
        uint256 n = evidenceHashes.length;
        require(
            verdictHashes.length == n &&
                policyIds.length == n &&
                agents.length == n &&
                verdicts.length == n &&
                paymentRefs.length == n,
            "length mismatch"
        );
        for (uint256 i = 0; i < n; ) {
            attest(
                verdictHashes[i],
                evidenceHashes[i],
                policyIds[i],
                agents[i],
                verdicts[i],
                paymentRefs[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Revoke/supersede a verdict without deleting it. History stays
     *         intact for forensics; the record is flagged and can point to
     *         the correcting attestation.
     */
    function revoke(bytes32 evidenceHash, bytes32 supersededBy)
        external
        onlyAttester
    {
        Attestation storage a = attestations[evidenceHash];
        require(a.timestamp != 0, "unknown attestation");
        require(!a.revoked, "already revoked");
        a.revoked = true;
        a.supersededBy = supersededBy;
        emit Revoked(evidenceHash, supersededBy);
    }

    /**
     * @notice Attach or replace free-form metadata for an attestation. This
     *         is the forward-compatibility slot: any data VETO has not yet
     *         designed can bind to a verdict here without a redeploy.
     */
    function setMetadata(bytes32 evidenceHash, bytes calldata data)
        external
        onlyAttester
    {
        require(attestations[evidenceHash].timestamp != 0, "unknown attestation");
        metadata[evidenceHash] = data;
        emit MetadataSet(evidenceHash);
    }

    /**
     * @notice Bind an x402 payment reference to an existing attestation
     *         (for flows where the verdict is written before settlement).
     */
    function bindPayment(bytes32 evidenceHash, bytes32 paymentRef)
        external
        onlyAttester
    {
        Attestation storage a = attestations[evidenceHash];
        require(a.timestamp != 0, "unknown attestation");
        a.paymentRef = paymentRef;
        emit PaymentBound(evidenceHash, paymentRef);
    }

    // --------------------------------------------------------------- views

    /// @notice Verify an evidence hash was attested with the expected verdict.
    function verify(bytes32 evidenceHash, bytes32 verdictHash)
        external
        view
        returns (bool)
    {
        Attestation storage a = attestations[evidenceHash];
        return a.timestamp != 0 && !a.revoked && a.verdictHash == verdictHash;
    }

    /// @notice The full attestation record for an evidence hash.
    function get(bytes32 evidenceHash)
        external
        view
        returns (Attestation memory)
    {
        return attestations[evidenceHash];
    }

    /// @notice How many verdicts have been rendered for an agent.
    function agentCount(address agent) external view returns (uint256) {
        return _agentHistory[agent].length;
    }

    /// @notice A page of an agent's verdict history (evidence hashes).
    function agentHistory(address agent, uint256 offset, uint256 limit)
        external
        view
        returns (bytes32[] memory page)
    {
        bytes32[] storage h = _agentHistory[agent];
        if (offset >= h.length) return new bytes32[](0);
        uint256 end = offset + limit;
        if (end > h.length) end = h.length;
        page = new bytes32[](end - offset);
        for (uint256 i = offset; i < end; ) {
            page[i - offset] = h[i];
            unchecked {
                ++i;
            }
        }
    }

    // ------------------------------------------------------------- admin

    function setAttester(address who, bool allowed) external onlyOwner {
        attesters[who] = allowed;
        emit AttesterSet(who, allowed);
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
        emit Paused(p);
    }

    function transferOwnership(address to) external onlyOwner {
        pendingOwner = to;
        emit OwnershipTransferStarted(owner, to);
    }

    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "not pending owner");
        address prev = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(prev, owner);
    }
}
