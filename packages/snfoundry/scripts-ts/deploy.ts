import {
    deployContract,
    executeDeployCalls,
    exportDeployments,
    deployer,
    parseUnits,
} from "./deploy-contract";
import { green } from "./helpers/colorize-log";

/**
 *  Deploy a contract using the specified parameters.
 *  @example (deploy contract with contructorArgs)
 *  */

interface DeployedAddresses {
    amAddress: string;
    dscAddress: string;
    pragmaAddress: string;
    pragmaCustomAddress: string;
    lendingPoolAddress: string;
}

const deployScript = async (): Promise<DeployedAddresses> => {
    console.log("deployer.address", deployer.address);
    /// deploy asset manager
    const amResult = await deployContract({
        contract: "AssetManager",
        contractName: "AssetManager",
        constructorArgs: {
            owner: deployer.address,
        },
    });
    const amAddress = amResult.address;

    /// deploy dsc token
    const dscResult = await deployContract({
        contract: "DSCToken",
        contractName: "DSCToken",
        constructorArgs: {
            owner: deployer.address,
        },
    });
    const dscAddress = dscResult.address;

    const pragmaAddress = process.env.PRAGMA_ADDRESS_SEPOLIA;

    const pragmaCustomResult = await deployContract({
        contract: "PragmaCustom",
        contractName: "PragmaCustom",
        constructorArgs: {
            oracle: pragmaAddress,
            freshness_threshold: 30 * 60,
            sources_threshold: 3,
        },
    });
    const pragmaCustomAddress = pragmaCustomResult.address;

    // Deploy LendingPool
    const lendingPoolResult = await deployContract({
        contract: "LendingPool",
        contractName: "LendingPool",
        constructorArgs: {
            owner: deployer.address,
            dsc_token: dscAddress,
            reward_per_block: parseUnits("1", 15),
            asset_manager: amAddress,
            oracle_address: pragmaCustomAddress,
        },
    });
    const lendingPoolAddress = lendingPoolResult.address;

    return {
        amAddress,
        dscAddress,
        pragmaAddress,
        pragmaCustomAddress,
        lendingPoolAddress,
    };
};

deployScript()
    .then(async (addresses) => {
        executeDeployCalls()
            .then(() => {
                exportDeployments();
                console.log(green("All Setup Done"));
                console.log("Deployed Addresses:", addresses);
            })
            .catch((e) => {
                console.error(e);
                process.exit(1); // exit with error so that non subsequent scripts are run
            });
    })
    .catch(console.error);
