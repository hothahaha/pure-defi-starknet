import { useState } from "react";
import { useAccount } from "@starknet-react/core";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-stark/useScaffoldWriteContract";
import { formatUnits, parseUnits } from "ethers";
import { toast } from "react-hot-toast";
import { UserAsset } from "./types";

export function AssetCard({
    asset,
    onRefresh,
}: {
    asset: UserAsset;
    onRefresh: () => Promise<void>;
}) {
    const [isWithdrawModalOpen, setIsWithdrawModalOpen] = useState(false);
    const [isRepayModalOpen, setIsRepayModalOpen] = useState(false);
    const { address } = useAccount();

    const { sendAsync: withdraw, isPending: isWithdrawing } = useScaffoldWriteContract({
        contractName: "LendingPool",
        functionName: "withdraw",
        args: [asset.address, address, "0"],
    });

    const { sendAsync: repay, isPending: isRepaying } = useScaffoldWriteContract({
        contractName: "LendingPool",
        functionName: "repay",
        args: [asset.address, address, "0"],
    });

    const { sendAsync: claimReward, isPending: isClaiming } = useScaffoldWriteContract({
        contractName: "LendingPool",
        functionName: "claim_reward",
        args: [asset.address, address],
    });

    const handleWithdraw = async (amount: string) => {
        try {
            await withdraw({
                args: [asset.address, address, parseUnits(amount, 18)],
            });
            toast.success("Withdrawal successful!");
            setIsWithdrawModalOpen(false);
            onRefresh();
        } catch (error) {
            console.error("Withdrawal failed:", error);
            toast.error("Withdrawal failed");
        }
    };

    const handleRepay = async (amount: string) => {
        try {
            await repay({
                args: [asset.address, address, parseUnits(amount, 18)],
            });
            toast.success("Repayment successful!");
            setIsRepayModalOpen(false);
            onRefresh();
        } catch (error) {
            console.error("Repayment failed:", error);
            toast.error("Repayment failed");
        }
    };

    const handleClaimReward = async () => {
        try {
            await claimReward({
                args: [asset.address, address],
            });
            toast.success("Rewards claimed!");
            onRefresh();
        } catch (error) {
            console.error("Claim failed:", error);
            toast.error("Failed to claim rewards");
        }
    };

    return (
        <div className="card bg-base-100 shadow-xl">
            <div className="card-body">
                <div className="flex items-center gap-2">
                    <img
                        src={asset.icon}
                        alt={asset.symbol}
                        className="w-8 h-8"
                    />
                    <h2 className="card-title">{asset.symbol}</h2>
                </div>

                <div className="mt-4 space-y-2">
                    {Number(asset.depositAmount) > 0 && (
                        <div>
                            <p className="text-sm opacity-70">Your Deposits</p>
                            <p className="text-xl font-semibold">
                                {asset.depositAmount} {asset.symbol}
                            </p>
                            <p className="text-sm text-success">${asset.depositValue}</p>
                        </div>
                    )}

                    {Number(asset.borrowAmount) > 0 && (
                        <div>
                            <p className="text-sm opacity-70">Your Borrows</p>
                            <p className="text-xl font-semibold">
                                {asset.borrowAmount} {asset.symbol}
                            </p>
                            <p className="text-sm text-warning">${asset.borrowValue}</p>
                        </div>
                    )}

                    {Number(asset.pendingRewards) > 0 && (
                        <div>
                            <p className="text-sm opacity-70">Pending Rewards</p>
                            <p className="text-xl font-semibold">{asset.pendingRewards} DSC</p>
                        </div>
                    )}
                </div>

                <div className="card-actions justify-end mt-4">
                    {Number(asset.depositAmount) > 0 && (
                        <button
                            className="btn btn-primary btn-sm"
                            onClick={() => setIsWithdrawModalOpen(true)}
                            disabled={isWithdrawing}
                        >
                            {isWithdrawing ? (
                                <span className="loading loading-spinner" />
                            ) : (
                                "Withdraw"
                            )}
                        </button>
                    )}

                    {Number(asset.borrowAmount) > 0 && (
                        <button
                            className="btn btn-secondary btn-sm"
                            onClick={() => setIsRepayModalOpen(true)}
                            disabled={isRepaying}
                        >
                            {isRepaying ? <span className="loading loading-spinner" /> : "Repay"}
                        </button>
                    )}

                    {Number(asset.pendingRewards) > 0 && (
                        <button
                            className="btn btn-accent btn-sm"
                            onClick={handleClaimReward}
                            disabled={isClaiming}
                        >
                            {isClaiming ? <span className="loading loading-spinner" /> : "Claim"}
                        </button>
                    )}
                </div>
            </div>
        </div>
    );
}
