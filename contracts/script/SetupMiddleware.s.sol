// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {IncredibleSquaringDeploymentLib} from "../script/utils/IncredibleSquaringDeploymentLib.sol";
import {IStrategy} from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import {CoreDeploymentLib} from "./utils/CoreDeploymentLib.sol";
import {
    AllocationManager,
    IAllocationManager,
    IAllocationManagerTypes
} from "@eigenlayer/contracts/core/AllocationManager.sol";
import {
    ISlashingRegistryCoordinator,
    ISlashingRegistryCoordinatorTypes
} from "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistryTypes} from "@eigenlayer-middleware/src/StakeRegistry.sol";

contract SetupMiddleware is Script {
    address internal deployer;
    IncredibleSquaringDeploymentLib.DeploymentData internal deploymentData;
    CoreDeploymentLib.DeploymentData internal coreData;

    // Configuration struct to hold quorum parameters with proper types
    struct QuorumConfig {
        uint96 minimumStake;
        uint32 maxOperatorCount;
        uint16 kickBIPsOfOperatorStake;
        uint16 kickBIPsOfTotalStake;
        string metadataURI;
    }

    function setUp() public virtual {
        deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        vm.label(deployer, "Deployer");
        deploymentData = IncredibleSquaringDeploymentLib.readDeploymentJson(block.chainid);
        coreData = CoreDeploymentLib.readDeploymentJson("script/deployments/core/", block.chainid);
    }

    /**
     * @notice Reads quorum configuration from docker/eigenlayer/config.json
     * @dev Minimum stake and other quorum parameters are configured in docker/eigenlayer/config.json.
     *      To change the minimum stake, edit the "minimumStake" field in that file.
     *      This allows for easy configuration without code changes.
     * @return config The quorum configuration parameters
     */
    function readQuorumConfig() internal view returns (QuorumConfig memory config) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/docker/eigenlayer/config.json");
        string memory json = vm.readFile(path);

        // Cast JSON values to the appropriate types
        config.minimumStake = uint96(vm.parseJsonUint(json, "$.quorum.minimumStake"));
        config.maxOperatorCount = uint32(vm.parseJsonUint(json, "$.quorum.maxOperatorCount"));
        config.kickBIPsOfOperatorStake = uint16(vm.parseJsonUint(json, "$.quorum.kickBIPsOfOperatorStake"));
        config.kickBIPsOfTotalStake = uint16(vm.parseJsonUint(json, "$.quorum.kickBIPsOfTotalStake"));
        config.metadataURI = vm.parseJsonString(json, "$.metadata.uri");
    }

    function run() external {
        vm.startBroadcast(deployer);

        QuorumConfig memory config = readQuorumConfig();

        address operatorSetStrategy = vm.envAddress("LST_STRATEGY_ADDRESS");
        require(operatorSetStrategy != address(0), "LST_STRATEGY_ADDRESS env var not set or invalid");
        string memory metadataURI = config.metadataURI;

        IAllocationManager(coreData.allocationManager).updateAVSMetadataURI(
            deploymentData.incredibleSquaringServiceManager, metadataURI
        );
        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(operatorSetStrategy);

        IStakeRegistryTypes.StrategyParams[] memory strategyParamsArray =
            new IStakeRegistryTypes.StrategyParams[](strategies.length);
        for (uint256 i = 0; i < strategies.length; i++) {
            strategyParamsArray[i] = IStakeRegistryTypes.StrategyParams({strategy: strategies[i], multiplier: 1 ether});
        }

        ISlashingRegistryCoordinator(deploymentData.slashingRegistryCoordinator).createSlashableStakeQuorum(
            ISlashingRegistryCoordinatorTypes.OperatorSetParam({
                maxOperatorCount: config.maxOperatorCount,
                kickBIPsOfOperatorStake: config.kickBIPsOfOperatorStake,
                kickBIPsOfTotalStake: config.kickBIPsOfTotalStake
            }),
            config.minimumStake,
            strategyParamsArray,
            0
        );

        vm.stopBroadcast();
    }
}
