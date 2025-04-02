// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {BTCAddressRegistry} from "./BTCAddressRegistry.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract GoatHTLC is BTCAddressRegistry {
    using SafeERC20 for IERC20;
    constructor() {}

    enum TransferStatus {
        Null,
        Pending,
        Claim,
        Refunded
    }
    struct Transfer {
        address sender;
        address receiver;
        address token;
        uint256 amount;
        bytes32 hashLock; // hash of the preimage
        uint64 timeLock; // UNIX timestamp seconds - locked UNTIL this time
        TransferStatus status;
    }

    struct TransferInParams {
        address dstEthAddr;
        address token;
        uint256 amount;
        uint32 secretLength;
        bytes32 hashLock;
        uint64 timeLock;
        NetworkType network;
        BTCAddressType addrType;
        string claimBtcAddr;
    }

    mapping(bytes32 => Transfer) public transfers;

    event LogNewTransferIn(
        bytes32 transferId,
        address indexed sender,
        address indexed receiver,
        address token,
        uint256 amount,
        string  refundBtcAddr
    );
    event LogTransferConfirmed(bytes32 transferId, bytes32 preimage);
    event LogTransferRefunded(bytes32 transferId);

      /**
     * @dev transfer sets up a new inbound transfer with hash time lock.
     */
    function transferIn(
        TransferInParams memory _params
    ) external validateAddressWithNetwork(_params.network, _params.claimBtcAddr) {
        // TODO feeRate check
        string memory refundBtcAddr = getBTCAddressByType(_params.dstEthAddr, _params.network,
            _params.addrType);
        require(bytes(refundBtcAddr).length > 0, "No btc address found");

        bytes32 transferId = _transfer(_params.dstEthAddr, _params.token, _params.amount,
            _params.hashLock, _params.timeLock);
        emit LogNewTransferIn(
            transferId,
            msg.sender,
            _params.dstEthAddr,
            _params.token,
            _params.amount,
            refundBtcAddr
        );
    }

    /**
     * @dev redeem a transfer.
     *
     * @param _transferId Id of pending transfer.
     * @param _preimage key for the hashlock
     */
    function claim(bytes32 _transferId, bytes32 _preimage) external {
        Transfer memory t = transfers[_transferId];

        require(t.status == TransferStatus.Pending, "not pending transfer");
        require(t.hashLock == keccak256(abi.encodePacked(_preimage)), "incorrect preimage");

        transfers[_transferId].status = TransferStatus.Claim;

        IERC20(t.token).safeTransfer(t.receiver, t.amount);
        emit LogTransferConfirmed(_transferId, _preimage);
    }

    /**
     * @dev refund a transfer after timeout.
     *
     * @param _transferId Id of pending transfer.
     */
    function refund(bytes32 _transferId) external {
        Transfer memory t = transfers[_transferId];

        require(t.status == TransferStatus.Pending, "not pending transfer");
        require(t.timeLock <= block.timestamp, "timelock not yet passed");

        transfers[_transferId].status = TransferStatus.Refunded;

        IERC20(t.token).safeTransfer(t.sender, t.amount);
        emit LogTransferRefunded(_transferId);
    }

    /**
     * @dev transfer sets up a new transfer with hash time lock.
     */
    function _transfer(
        address _receiver,
        address _token,
        uint256 _amount,
        bytes32 _hashLock,
        uint64 _timeLock
    ) private returns (bytes32 transferId) {
        require(_amount > 0, "invalid amount");
        require(_timeLock > block.timestamp, "invalid timelock");

        transferId = keccak256(abi.encodePacked(msg.sender, _receiver, _hashLock, block.chainid));
        require(transfers[transferId].status == TransferStatus.Null, "transfer exists");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        transfers[transferId] = Transfer(
            msg.sender,
            _receiver,
            _token,
            _amount,
            _hashLock,
            _timeLock,
            TransferStatus.Pending
        );
        return transferId;
    }
}