// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {IncredibleSquaringDeploymentLib} from "../script/utils/IncredibleSquaringDeploymentLib.sol";
import {IStrategy} from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import {CoreDeploymentLib} from "./utils/CoreDeploymentLib.sol";
import {AllocationManager, IAllocationManager, IAllocationManagerTypes} from "@eigenlayer/contracts/core/AllocationManager.sol";
import {
    ISlashingRegistryCoordinator,
    ISlashingRegistryCoordinatorTypes
} from "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistryTypes} from "@eigenlayer-middleware/src/StakeRegistry.sol";

contract SetupMiddleware is Script {
    address internal deployer;
    IncredibleSquaringDeploymentLib.DeploymentData internal deploymentData;
    CoreDeploymentLib.DeploymentData internal coreData;

    function setUp() public virtual {
        deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        vm.label(deployer, "Deployer");
        deploymentData = IncredibleSquaringDeploymentLib.readDeploymentJson(block.chainid);
        coreData = CoreDeploymentLib.readDeploymentJson("script/deployments/core/", block.chainid);
    }

    function run() external {
        vm.startBroadcast(deployer);

        address operatorSetStrategy = 0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3;
        string memory metadataURI = "metadataURI";

        IAllocationManager(coreData.allocationManager).updateAVSMetadataURI(
            deploymentData.incredibleSquaringServiceManager, metadataURI
        );
        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(operatorSetStrategy);
        // IAllocationManagerTypes.CreateSetParams[] memory createSetParams = new IAllocationManagerTypes.CreateSetParams[](1);
        // createSetParams[0] = IAllocationManagerTypes.CreateSetParams({
        //     operatorSetId: 1,
        //     strategies: strategies
        // });
        // IAllocationManager(coreData.allocationManager).createOperatorSets(
        //     deploymentData.incredibleSquaringServiceManager,
        //     createSetParams
        // );

        IStakeRegistryTypes.StrategyParams[] memory strategyParamsArray = new IStakeRegistryTypes.StrategyParams[](strategies.length);
        for (uint256 i = 0; i < strategies.length; i++) {
            strategyParamsArray[i] = IStakeRegistryTypes.StrategyParams({
                strategy: strategies[i],
                multiplier: 1 ether  // TODO: needs oracle
            });
        }
        ISlashingRegistryCoordinator(deploymentData.slashingRegistryCoordinator).createSlashableStakeQuorum(
            ISlashingRegistryCoordinatorTypes.OperatorSetParam({
                maxOperatorCount: 32,
                kickBIPsOfOperatorStake: 10000,  // TODO: chosen arbitrarily
                kickBIPsOfTotalStake: 100  // TODO: chosen arbitrarily
            }),
            1, //TODO fix this to a real min
            strategyParamsArray,
            0
        );

        vm.stopBroadcast();
    }
}
