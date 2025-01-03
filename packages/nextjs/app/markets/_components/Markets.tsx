"use client";

import { useEffect, useState } from "react";
import { useAccount } from "~~/hooks/useAccount";
import { useDeployedContractInfo } from "~~/hooks/scaffold-stark";
import { MarketCard } from "./MarketCard";
import { MarketStats } from "./MarketStats";
import { useContract } from "@starknet-react/core";

export function Markets() {
    const { isConnected } = useAccount();
    const { data: lendingPoolContract } = useDeployedContractInfo("LendingPool");
    const { contract } = useContract({
        abi: lendingPoolContract?.abi,
        address: lendingPoolContract?.address,
    });

    const [markets, setMarkets] = useState<any[]>([]);
    const [totalDeposits, setTotalDeposits] = useState<string>("0");
    const [totalBorrows, setTotalBorrows] = useState<string>("0");

    useEffect(() => {
        if (!contract) return;

        // 获取市场数据
        const fetchMarkets = async () => {
            // TODO: 从合约获取支持的资产列表和数据
            const mockMarkets = [
                {
                    symbol: "ETH",
                    depositAPY: "3.5",
                    borrowAPY: "5.2",
                    totalDeposited: "1,234.56",
                    totalBorrowed: "789.12",
                    walletBalance: "2.5",
                    depositBalance: "1.2",
                    borrowBalance: "0.5",
                },
                {
                    symbol: "STRK",
                    depositAPY: "8.1",
                    borrowAPY: "12.4",
                    totalDeposited: "5,678,901.23",
                    totalBorrowed: "3,456,789.01",
                    walletBalance: "10000",
                    depositBalance: "5000",
                    borrowBalance: "2000",
                },
            ];
            setMarkets(mockMarkets);
        };

        fetchMarkets();
    }, [contract]);

    return (
        <div className="flex flex-col gap-y-6 lg:gap-y-8 py-8 lg:py-12 justify-center items-center">
            <MarketStats
                totalDeposits={totalDeposits}
                totalBorrows={totalBorrows}
            />

            <div className="w-full max-w-7xl px-6 lg:px-10">
                <div className="overflow-x-auto">
                    <table className="table w-full">
                        <thead>
                            <tr className="text-base">
                                <th>Asset</th>
                                <th>Total Deposited</th>
                                <th>Total Borrowed</th>
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
                            {markets.map((market, index) => (
                                <MarketCard
                                    key={index}
                                    market={market}
                                    isConnected={isConnected}
                                />
                            ))}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
}
