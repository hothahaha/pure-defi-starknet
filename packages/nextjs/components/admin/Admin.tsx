"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useAccount } from "@starknet-react/core";
import { useScaffoldReadContract } from "~~/hooks/scaffold-stark/useScaffoldReadContract";
import { formatUnits } from "ethers";
import { AssetCard } from "./AssetCard";
import { UserStats } from "./UserStats";
import { UserAsset } from "./types";
import { toast } from "react-hot-toast";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-stark/useScaffoldWriteContract";

export function Admin() {
    const { address, isConnected } = useAccount();
    const [isClaiming, setIsClaiming] = useState(false);
    const [totalDeposit, setTotalDeposit] = useState("0");
    const [totalBorrow, setTotalBorrow] = useState("0");

    // 获取支持的资产列表
    const { data: supportedAssets } = useScaffoldReadContract({
        contractName: "AssetManager",
        functionName: "get_supported_assets",
        args: [],
    });

    // 获取资产配置
    const { data: assetConfigs } = useScaffoldReadContract({
        contractName: "AssetManager",
        functionName: "get_asset_configs",
        args: supportedAssets ? [[...supportedAssets]] : ([] as any),
    });

    // 获取用户资产信息
    const { data: userDataList, refetch: refetchUserData } = useScaffoldReadContract({
        contractName: "LendingPool",
        functionName: "get_user_infos",
        args: supportedAssets ? [address, [...supportedAssets]] : ([] as any),
    });

    // 获取用户总价值
    const { data: userTotalValue } = useScaffoldReadContract({
        contractName: "LendingPool",
        functionName: "get_user_total_value_in_usd",
        args: [address],
    });

    // 获取用户奖励
    const { data: pendingRewards } = useScaffoldReadContract({
        contractName: "LendingPool",
        functionName: "get_pending_rewards",
        args: supportedAssets ? [address, [...supportedAssets]] : ([] as any),
    });

    // 将 claim 函数移到组件内部
    const { sendAsync: claimReward } = useScaffoldWriteContract({
        contractName: "LendingPool",
        functionName: "claim_reward",
        args: [address],
    });

    // 处理用户资产数据
    const userAssets = useMemo(() => {
        if (!supportedAssets?.length || !assetConfigs?.length || !userDataList?.length) return [];

        return supportedAssets
            .map((address: any, index: any) => {
                const config = assetConfigs[index];
                const userData = userDataList[index];
                const rewards = pendingRewards?.[index];

                const depositAmount = formatUnits(userData?.deposit_amount?.toString() || "0", 18);
                const borrowAmount = formatUnits(userData?.borrow_amount?.toString() || "0", 18);

                // 只返回有存款或借款的资产
                if (Number(depositAmount) === 0 && Number(borrowAmount) === 0) return null;

                return {
                    address: address.toString(),
                    symbol: config.symbol || "",
                    name: config.name || "",
                    icon: config.icon || "",
                    depositAmount,
                    borrowAmount,
                    depositValue: formatUnits(userData?.deposit_amount_usd?.toString() || "0", 18),
                    borrowValue: formatUnits(userData?.borrow_amount_usd?.toString() || "0", 18),
                    pendingRewards: formatUnits(rewards?.toString() || "0", 18),
                };
            })
            .filter(Boolean);
    }, [supportedAssets, assetConfigs, userDataList, pendingRewards]);

    // 使用 useEffect 来更新统计数据
    useEffect(() => {
        const depositValue = userAssets.reduce(
            (acc, asset) => acc + Number(asset?.depositValue || 0),
            0
        );
        const borrowValue = userAssets.reduce(
            (acc, asset) => acc + Number(asset?.borrowValue || 0),
            0
        );
        setTotalDeposit(depositValue.toFixed(2));
        setTotalBorrow(borrowValue.toFixed(2));
    }, [userAssets]);

    // 刷新数据
    const refreshData = useCallback(async () => {
        if (!address) return;
        await refetchUserData();
    }, [address, refetchUserData]);

    const totalRewards = useMemo(() => {
        return userAssets.reduce(
            (total: any, asset: any) => total + Number(asset?.pendingRewards || 0),
            0
        );
    }, [userAssets]);

    // 处理 claim all 的函数也移到组件内部
    const handleClaimAll = useCallback(async () => {
        if (!address) return;

        try {
            setIsClaiming(true);
            await claimReward({
                args: [address],
            });
            toast.success("Rewards claimed successfully!");
            await refreshData();
        } catch (error) {
            console.error("Failed to claim rewards:", error);
            toast.error("Failed to claim rewards");
        } finally {
            setIsClaiming(false);
        }
    }, [address, claimReward, refreshData]);

    if (!isConnected) {
        return (
            <div className="flex justify-center items-center h-[70vh]">
                <p className="text-xl">Please connect your wallet to view your dashboard</p>
            </div>
        );
    }

    return (
        <div className="bg-base-200 h-[calc(100vh-4rem-3rem)] overflow-hidden">
            <div className="container mx-auto max-w-7xl h-full px-4 py-6 flex flex-col">
                <h1 className="text-4xl font-bold mb-6">Your Dashboard</h1>

                <UserStats
                    totalDeposit={totalDeposit}
                    totalBorrow={totalBorrow}
                />

                <div className="mt-6 flex-1 min-h-0 overflow-hidden">
                    <div className="h-full overflow-y-auto">
                        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 pb-4 pr-2">
                            {userAssets.map((asset: any) => (
                                <AssetCard
                                    key={asset?.address}
                                    asset={asset as UserAsset}
                                    onRefresh={refreshData}
                                />
                            ))}
                        </div>
                    </div>
                </div>

                <div className="mt-6 bg-base-100 rounded-box shadow-lg p-4">
                    <div className="flex justify-between items-center">
                        <div>
                            <p className="text-sm opacity-70">Total Pending Rewards</p>
                            <p className="text-xl font-semibold">
                                {userAssets
                                    .reduce(
                                        (total: any, asset: any) =>
                                            total + Number(asset?.pendingRewards || 0),
                                        0
                                    )
                                    .toFixed(4)}{" "}
                                DSC
                            </p>
                        </div>
                        <button
                            className="btn btn-accent"
                            onClick={handleClaimAll}
                            disabled={isClaiming || totalRewards <= 0}
                        >
                            {isClaiming ? (
                                <span className="loading loading-spinner" />
                            ) : (
                                "Claim All"
                            )}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
