"use client";

import { useEffect, useState, useMemo, useCallback } from "react";
import { useAccount } from "~~/hooks/useAccount";
import { useScaffoldReadContract } from "~~/hooks/scaffold-stark/useScaffoldReadContract";
import { Asset } from "./types";
import { AssetCard } from "./AssetCard";
import { AssetForm } from "./AssetForm";
import { formatUnits } from "ethers";
import { toast } from "react-hot-toast";

export function AssetManager() {
    const { address, isConnected } = useAccount();
    const [isFormOpen, setIsFormOpen] = useState(false);
    const [editingAsset, setEditingAsset] = useState<Asset | undefined>();
    const [newAsset, setNewAsset] = useState<Asset | any>();
    const [refreshTrigger, setRefreshTrigger] = useState(0);

    // 获取支持的资产列表
    const { data: supportedAssets, refetch: refetchAssets } = useScaffoldReadContract({
        contractName: "AssetManager",
        functionName: "get_supported_assets",
        args: [],
    });

    // 批量获取资产配置
    const { data: assetConfigs, refetch: refetchConfigs } = useScaffoldReadContract({
        contractName: "AssetManager",
        functionName: "get_asset_configs",
        args: supportedAssets ? [[...supportedAssets]] : ([] as any),
    });

    // 批量获取市场数据
    const { data: marketDataList, refetch: refetchMarkets } = useScaffoldReadContract({
        contractName: "LendingPool",
        functionName: "get_asset_infos",
        args: supportedAssets ? [[...supportedAssets], address] : ([] as any),
    });

    const refreshData = useCallback(async () => {
        try {
            // 并行获取所有数据
            await Promise.all([refetchAssets(), refetchConfigs(), refetchMarkets()]);

            // 触发状态更新
            setRefreshTrigger((prev) => prev + 1);
        } catch (error) {
            console.error("Failed to refresh data:", error);
            toast.error("Failed to refresh asset data");
        }
    }, [refetchAssets, refetchConfigs, refetchMarkets]);

    // 处理资产数据
    const assets = useMemo(() => {
        console.log("supportedAssets", supportedAssets);
        console.log("assetConfigs", assetConfigs);
        console.log("marketDataList", marketDataList);
        if (!supportedAssets?.length || !assetConfigs?.length || !marketDataList?.length) return [];

        return supportedAssets
            .map((address: any, index: any) => {
                const config = assetConfigs[index];
                const marketData = marketDataList[index];

                if (!config || !marketData) return null;

                return {
                    address: address.toString(),
                    symbol: config.symbol || "",
                    name: config.name || "",
                    decimals: config.decimals?.toString() || "18",
                    icon: config.icon || "",
                    isSupported: Boolean(config.is_supported),
                    collateralFactor: formatUnits(config.collateral_factor?.toString() || "0", 18),
                    borrowFactor: formatUnits(config.borrow_factor?.toString() || "0", 18),
                    totalDeposits: formatUnits(marketData.total_deposits?.toString() || "0", 18),
                    totalBorrows: formatUnits(marketData.total_borrows?.toString() || "0", 18),
                };
            })
            .filter((asset: any): asset is Asset => asset !== null);
    }, [supportedAssets, assetConfigs, marketDataList]);

    return (
        <div className="bg-base-200">
            <div className="container mx-auto max-w-7xl px-4 py-8">
                <div className="flex justify-between items-center mb-8">
                    <h1 className="text-4xl font-bold">Asset Management</h1>
                    {isConnected && (
                        <button
                            onClick={() => setIsFormOpen(true)}
                            className="btn btn-primary"
                        >
                            Add Asset
                        </button>
                    )}
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {assets.map((asset: any) => (
                        <AssetCard
                            key={asset.address}
                            asset={asset}
                            onEdit={(asset) => setEditingAsset(asset)}
                        />
                    ))}
                </div>

                {isFormOpen && (
                    <AssetForm
                        asset={newAsset}
                        onClose={() => setIsFormOpen(false)}
                        onRefresh={refreshData}
                        onSubmit={() => {
                            refreshData;
                        }}
                    />
                )}

                {editingAsset && (
                    <AssetForm
                        asset={editingAsset}
                        onClose={() => setEditingAsset(undefined)}
                        onRefresh={refreshData}
                        onSubmit={() => {
                            refreshData;
                        }}
                    />
                )}
            </div>
        </div>
    );
}
