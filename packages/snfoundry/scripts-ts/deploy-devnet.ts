import {
    deployContract,
    executeDeployCalls,
    deployer,
    parseUnits,
    networkName,
    networks,
    feeToken,
    getTxVersion,
    provider,
    TransactionReceipt,
    exportDeployments,
} from "./deploy-contract";
import { green } from "./helpers/colorize-log";
import { Call } from "starknet";

interface DeployedAddresses {
    amAddress: string;
    dscAddress: string;
    mockPragmaAddress: string;
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

    /// deploy Pragma
    const mockPragmaResult = await deployContract({
        contract: "MockPragma",
        contractName: "MockPragma",
    });
    const mockPragmaAddress = mockPragmaResult.address;

    const pragmaCustomResult = await deployContract({
        contract: "PragmaCustom",
        contractName: "PragmaCustom",
        constructorArgs: {
            oracle: mockPragmaAddress,
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
            token_addresses: [
                "0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7",
                "0x4718F5A0FC34CC1AF16A1CDEE98FFB20C31F5CD61D6AB07201858F4287C938D",
            ],
            pair_ids: ["ETH/USD", "STRK/USD"],
            oracle_address: pragmaCustomAddress,
        },
    });
    const lendingPoolAddress = lendingPoolResult.address;

    return {
        amAddress,
        dscAddress,
        mockPragmaAddress,
        pragmaCustomAddress,
        lendingPoolAddress,
    };
};

const executeScript = async (addresses: DeployedAddresses): Promise<void> => {
    const { amAddress, dscAddress, mockPragmaAddress, pragmaCustomAddress, lendingPoolAddress } =
        addresses;

    // 等待几秒确保合约部署完成
    await new Promise((resolve) => setTimeout(resolve, 5000));

    // 配置合约调用
    const setupCalls: Call[] = [
        {
            contractAddress: lendingPoolAddress,
            entrypoint: "add_yangs_to_pragma",
            calldata: [
                pragmaCustomAddress,
                [
                    "0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
                    "0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
                ],
            ],
        },
    ];

    console.log("networkName: ", networkName);
    // 逐个执行初始化调用
    for (const call of setupCalls) {
        try {
            const txVersion = await getTxVersion(networks[networkName], feeToken);
            const { transaction_hash } = await deployer.execute([call], {
                version: txVersion,
            });

            if (networkName === "sepolia" || networkName === "mainnet") {
                const receipt = (await provider.waitForTransaction(
                    transaction_hash
                )) as TransactionReceipt;
                if (receipt.execution_status !== "SUCCEEDED") {
                    throw new Error(`Setup call failed: ${receipt.revert_reason}`);
                }
            }
            console.log(green(`Setup call executed successfully: ${call.entrypoint}`));

            // 每次调用后等待一小段时间
            await new Promise((resolve) => setTimeout(resolve, 1000));
        } catch (error) {
            console.error(`Error executing setup call ${call.entrypoint}:`, error);
            throw error;
        }
    }
};

deployScript()
    .then(async (addresses) => {
        try {
            // 先执行部署后的配置
            // await executeScript(addresses);

            // 然后执行其他部署调用
            await executeDeployCalls();

            // 最后导出部署信息
            exportDeployments();

            console.log(green("All Setup Done"));
            console.log("Deployed Addresses:", addresses);
        } catch (error) {
            console.error("Error during deployment:", error);
            process.exit(1);
        }
    })
    .catch((error) => {
        console.error("Failed to deploy contracts:", error);
        process.exit(1);
    });
