"use client";

import { useCallback, useMemo } from "react";
import { useAccount } from "@starknet-react/core";
import { useScaffoldReadContract } from "~~/hooks/scaffold-stark/useScaffoldReadContract";
import { formatUnits } from "ethers";
import { AssetCard } from "./AssetCard";
import { UserStats } from "./UserStats";

export function Admin() {
    const { address, isConnected } = useAccount();

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

    // 处理用户资产数据
    const userAssets = useMemo(() => {
        if (!supportedAssets?.length || !assetConfigs?.length || !userDataList?.length) return [];

        return supportedAssets
            .map((address, index) => {
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
                    depositValue: formatUnits(userData?.deposit_value?.toString() || "0", 18),
                    borrowValue: formatUnits(userData?.borrow_value?.toString() || "0", 18),
                    pendingRewards: formatUnits(rewards?.toString() || "0", 18),
                };
            })
            .filter(Boolean);
    }, [supportedAssets, assetConfigs, userDataList, pendingRewards]);

    // 刷新数据
    const refreshData = useCallback(async () => {
        await refetchUserData();
    }, [refetchUserData]);

    if (!isConnected) {
        return (
            <div className="flex justify-center items-center h-[70vh]">
                <p className="text-xl">Please connect your wallet to view your dashboard</p>
            </div>
        );
    }

    return (
        <div className="flex flex-col gap-y-6 lg:gap-y-8 py-8 lg:py-12 justify-center items-center bg-base-200">
            <div className="w-full max-w-7xl">
                <h1 className="text-4xl font-bold mb-8">Your Dashboard</h1>

                <UserStats totalValue={formatUnits(userTotalValue?.[0]?.toString() || "0", 18)} />

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mt-8">
                    {userAssets.map((asset) => (
                        <AssetCard
                            key={asset.address}
                            asset={asset}
                            onRefresh={refreshData}
                        />
                    ))}
                </div>
            </div>
        </div>
    );
}
