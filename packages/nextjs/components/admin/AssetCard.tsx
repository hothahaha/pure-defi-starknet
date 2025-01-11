"use client";

import { useState } from "react";
import { UserAsset } from "./types";
import { WithdrawModal } from "./WithdrawModal";
import { RepayModal } from "./RepayModal";

export function AssetCard({
    asset,
    onRefresh,
}: {
    asset: UserAsset;
    onRefresh: () => Promise<void>;
}) {
    const [isWithdrawModalOpen, setIsWithdrawModalOpen] = useState(false);
    const [isRepayModalOpen, setIsRepayModalOpen] = useState(false);

    return (
        <>
            <div className="card bg-base-100 shadow-xl h-full flex flex-col">
                <div className="card-body flex flex-col justify-between">
                    <div>
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
                                        {Number(asset.depositAmount).toFixed(4)} {asset.symbol}
                                    </p>
                                    <p className="text-sm text-success">
                                        ${Number(asset.depositValue).toFixed(4)}
                                    </p>
                                </div>
                            )}

                            {Number(asset.borrowAmount) > 0 && (
                                <div>
                                    <p className="text-sm opacity-70">Your Borrows</p>
                                    <p className="text-xl font-semibold">
                                        {Number(asset.borrowAmount).toFixed(4)} {asset.symbol}
                                    </p>
                                    <p className="text-sm text-warning">
                                        ${Number(asset.borrowValue).toFixed(4)}
                                    </p>
                                </div>
                            )}
                        </div>
                    </div>

                    <div className="card-actions justify-end mt-4">
                        {Number(asset.depositAmount) > 0 && (
                            <button
                                className="btn btn-primary btn-sm"
                                onClick={() => setIsWithdrawModalOpen(true)}
                            >
                                Withdraw
                            </button>
                        )}

                        {Number(asset.borrowAmount) > 0 && (
                            <button
                                className="btn btn-secondary btn-sm"
                                onClick={() => setIsRepayModalOpen(true)}
                            >
                                Repay
                            </button>
                        )}
                    </div>
                </div>
            </div>

            {isWithdrawModalOpen && (
                <WithdrawModal
                    asset={asset}
                    isOpen={isWithdrawModalOpen}
                    onClose={() => setIsWithdrawModalOpen(false)}
                    onSuccess={onRefresh}
                />
            )}
            {isRepayModalOpen && (
                <RepayModal
                    asset={asset}
                    isOpen={isRepayModalOpen}
                    onClose={() => setIsRepayModalOpen(false)}
                    onSuccess={onRefresh}
                />
            )}
        </>
    );
}
