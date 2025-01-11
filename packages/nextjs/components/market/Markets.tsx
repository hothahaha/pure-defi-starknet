"use client";

import { useCallback, useMemo } from "react";
import { useAccount, useNetwork } from "@starknet-react/core";
import { useScaffoldReadContract } from "~~/hooks/scaffold-stark/useScaffoldReadContract";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-stark/useScaffoldWriteContract";
import { MarketCard } from "./MarketCard";
import { MarketStats } from "./MarketStats";
import { formatUnits } from "ethers";
import { devnet } from "@starknet-react/chains";
import deployedContracts from "~~/contracts/deployedContracts";
import { toast } from "react-hot-toast";

export function Markets() {
    const { address, isConnected } = useAccount();
    const { chain } = useNetwork();

    // 检查是否是部署者地址
    const isDeployer =
        address?.toLowerCase() === process.env.NEXT_PUBLIC_ACCOUNT_ADDRESS_DEVNET?.toLowerCase();
    // 检查是否是 devnet 网络
    const isDevnet = chain?.id === devnet.id && chain?.network === devnet.network;

    // 获取支持的资产列表和相关数据
    const { data: supportedAssets, refetch: refetchAssets } = useScaffoldReadContract({
        contractName: "AssetManager",
        functionName: "get_supported_assets",
        args: [],
    });

    const { data: assetConfigs, refetch: refetchConfigs } = useScaffoldReadContract({
        contractName: "AssetManager",
        functionName: "get_asset_configs",
        args: supportedAssets ? [[...supportedAssets]] : ([] as any),
    });

    // 获取当前代币关联用户的存款和借款情况
    const { data: userDataList, refetch: refetchUserDatas } = useScaffoldReadContract({
        contractName: "LendingPool",
        functionName: "get_user_infos",
        args: supportedAssets ? [address, [...supportedAssets]] : ([] as any),
    });

    // 获取市场数据和用户余额
    const { data: marketDataList, refetch: refetchMarkets } = useScaffoldReadContract({
        contractName: "LendingPool",
        functionName: "get_asset_infos",
        args: supportedAssets ? [[...supportedAssets], address] : ([] as any),
    });

    // 计算总存款和总借款
    const { totalDeposits, totalBorrows } = useMemo(() => {
        if (!marketDataList?.length) return { totalDeposits: "0", totalBorrows: "0" };

        const totals = marketDataList.reduce(
            (acc: { totalDeposits: bigint; totalBorrows: bigint }, market: any) => ({
                totalDeposits:
                    acc.totalDeposits + BigInt(market.total_deposits_usd?.toString() || "0"),
                totalBorrows:
                    acc.totalBorrows + BigInt(market.total_borrows_usd?.toString() || "0"),
            }),
            { totalDeposits: 0n, totalBorrows: 0n }
        );

        return {
            totalDeposits: formatUnits(totals.totalDeposits, 18),
            totalBorrows: formatUnits(totals.totalBorrows, 18),
        };
    }, [marketDataList]);

    // 处理市场数据
    const markets = useMemo(() => {
        if (!supportedAssets?.length || !assetConfigs?.length || !marketDataList?.length) return [];

        return supportedAssets.map((address: any, index: any) => {
            const config = assetConfigs[index];
            const marketData = marketDataList[index];
            const userData = userDataList?.[index];

            const walletBalance = Number(
                formatUnits(marketData.user_balance?.toString() || "0", 18)
            );

            return {
                address: address.toString(),
                symbol: config.symbol || "",
                name: config.name || "",
                icon: config.icon || "",
                depositAPY: formatUnits(marketData.deposit_rate?.toString() || "0", 18),
                borrowAPY: formatUnits(marketData.borrow_rate?.toString() || "0", 18),
                asset_price: formatUnits(marketData.asset_price?.toString() || "0", 8),
                walletBalance: walletBalance.toFixed(4), // 四舍五入保留4位小数
                depositBalance: formatUnits(userData?.deposit_amount?.toString() || "0", 18),
                borrowBalance: formatUnits(userData?.borrow_amount?.toString() || "0", 18),
            };
        });
    }, [supportedAssets, assetConfigs, marketDataList, userDataList]);

    // 刷新数据
    const refreshData = useCallback(async () => {
        try {
            await Promise.all([
                refetchAssets(),
                refetchConfigs(),
                refetchMarkets(),
                refetchUserDatas(),
            ]);
        } catch (error) {
            console.error("Failed to refresh data:", error);
        }
    }, [refetchAssets, refetchConfigs, refetchMarkets, refetchUserDatas]);

    // 初始化 Pragma
    const { sendAsync: initPragma, isPending } = useScaffoldWriteContract({
        contractName: "LendingPool",
        functionName: "add_yangs_to_pragma",
        args: [undefined, undefined],
    });

    const handleInitPragma = async () => {
        try {
            const pragmaAddress = deployedContracts.devnet.PragmaCustom.address;
            const yangs = [
                "0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7",
                "0x4718F5A0FC34CC1AF16A1CDEE98FFB20C31F5CD61D6AB07201858F4287C938D",
            ];
            // const yangs = "0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7";

            console.log("args: ", [pragmaAddress, yangs]);
            await initPragma({
                args: [pragmaAddress, yangs],
            });
        } catch (error) {
            console.error("Error initializing Pragma:", error);
            toast.error("Error initializing Pragma");
        }
    };

    return (
        <div className="bg-base-200">
            <div className="container mx-auto max-w-7xl px-4 py-8">
                <div className="flex justify-between items-center mb-8">
                    <h1 className="text-4xl font-bold">Lending Markets</h1>

                    {/* 只在 devnet 和部署者地址时显示 initPragma 按钮 */}
                    {isDevnet && isDeployer && (
                        <button
                            className="btn btn-primary"
                            onClick={handleInitPragma}
                            disabled={isPending}
                        >
                            {isPending ? (
                                <span className="loading loading-spinner"></span>
                            ) : (
                                "Init Pragma"
                            )}
                        </button>
                    )}
                </div>

                <MarketStats
                    totalDeposits={totalDeposits}
                    totalBorrows={totalBorrows}
                />

                <div className="mt-8 bg-base-100 rounded-box shadow-lg">
                    <div className="overflow-x-auto">
                        <table className="table w-full">
                            <thead>
                                <tr className="text-base bg-base-300">
                                    <th>Asset</th>
                                    <th>Asset Price</th>
                                    <th>Deposit APY</th>
                                    <th>Borrow APY</th>
                                    <th>Wallet Balance</th>
                                    {isConnected && (
                                        <>
                                            <th>Your Deposits</th>
                                            <th>Your Borrows</th>
                                        </>
                                    )}
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {markets.map((market: any, index: any) => (
                                    <MarketCard
                                        key={index}
                                        market={market}
                                        isConnected={isConnected || false}
                                        onRefresh={refreshData}
                                    />
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    );
}
