// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Script} from "forge-std/Script.sol";
import {ISignatureUtils} from "@eigenlayer/contracts/interfaces/ISignatureUtils.sol";
import {IBLSApkRegistry} from "@eigenlayer-middleware/src/interfaces/IBLSApkRegistry.sol";
import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";
import {IRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import {RegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {BN256G2} from "src/libraries/BN256G2.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";

// Mainnet
// DELEGATION_MANAGER_ADDRESS=0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A
// Holesky
// DELEGATION_MANAGER_ADDRESS=0xA44151489861Fe9e3055d95adC98FbD462B948e7
// Mainnet
// STRATEGY_MANAGER_ADDRESS=0x858646372CC42E1A627fcE94aa7A7033e7CF075A
// Holesky
// STRATEGY_MANAGER_ADDRESS=0xdfB5f6CE42aAA7830E94ECFCcAd411beF4d4D5b6
// Holesky stETH
// LST_CONTRACT_ADDRESS=0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034
// Mainnet stETH
// LST_CONTRACT_ADDRESS=0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
// Holesky stETH strategy
// LST_STRATEGY_ADDRESS=0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3
// Mainnet stETH strategy
// LST_STRATEGY_ADDRESS=0x93c4b944D05dfe6df7645A86cd2206016c51564D

contract RegisterOperator is Script {
    using BN254 for BN254.G1Point;

    // Core contracts
    address constant DELEGATION_MANAGER_ADDRESS_HOLESKY = 0xA44151489861Fe9e3055d95adC98FbD462B948e7;
    address constant AVS_DIRECTORY_ADDRESS_HOLESKY = 0x055733000064333CaDDbC92763c58BF0192fFeBf;
    address constant STRATEGY_MANAGER_ADDRESS_HOLESKY = 0xdfB5f6CE42aAA7830E94ECFCcAd411beF4d4D5b6;
    // LST contracts
    address constant LST_CONTRACT_ADDRESS_HOLESKY = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
    address constant LST_STRATEGY_ADDRESS_HOLESKY = 0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3;
    // Opacity middleware contracts
    address constant OPACITY_REGISTRY_COORDINATOR_ADDRESS_HOLESKY = 0x3e43AA225b5cB026C5E8a53f62572b10D526a50B;
    address constant OPACTIY_AVS_ADDRESS_HOLESKY = 0xbfc5d26C6eEb46475eB3960F5373edC5341eE535;

    address registryCoordinatorMimicOwner = makeAddr("registryCoordinatorMimicOwner");


    struct Operator {
        address operator;
        uint256 ecdsaPrivateKey;
        uint256 blsPrivateKey;
        BN254.G1Point pk1;
        BN254.G2Point pk2;
    }
    function run() public {
        Operator memory operator = Operator({
            operator: makeAddr("operator"),
            ecdsaPrivateKey: 1,
            blsPrivateKey: 2,
        });
        registerOperator(IRegistryCoordinator(registryCoordinatorMimicOwner), OPACTIY_AVS_ADDRESS_HOLESKY, operator);
    }
    function registerOperator(IRegistryCoordinator registryCoordinator, address avs, Operator memory operator)
        internal
    {
        bytes memory quorumNumbers = hex"00";
        string memory socket = "foo.bar";

        BN254.G1Point memory h = registryCoordinator.pubkeyRegistrationMessageHash(operator.operator);
        BN254.G1Point memory sig = BN254.scalar_mul(h, operator.blsPrivateKey);

        IBLSApkRegistry.PubkeyRegistrationParams memory params = IBLSApkRegistry.PubkeyRegistrationParams({
            pubkeyG1: operator.pk1,
            pubkeyG2: operator.pk2,
            pubkeyRegistrationSignature: sig
        });

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature =
            _newOperatorRegistrationSignature(operator, avs, bytes32(0), block.timestamp + 1 days);

        vm.prank(operator.operator);
        RegistryCoordinator(address(registryCoordinator)).registerOperator(
            quorumNumbers, socket, params, operatorSignature
        );
    }

    function _newOperatorRegistrationSignature(Operator memory operator, address avs, bytes32 salt, uint256 expiry)
        internal
        view
        returns (ISignatureUtils.SignatureWithSaltAndExpiry memory)
    {
        bytes32 operatorRegistrationDigestHash = IAVSDirectory(AVS_DIRECTORY_ADDRESS_HOLESKY)
            .calculateOperatorAVSRegistrationDigestHash(operator.operator, avs, salt, expiry);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(operator.ecdsaPrivateKey, operatorRegistrationDigestHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        return ISignatureUtils.SignatureWithSaltAndExpiry({signature: signature, salt: salt, expiry: expiry});
    }
}