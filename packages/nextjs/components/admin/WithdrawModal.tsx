"use client";

import React, { useState } from "react";
import { useAccount } from "~~/hooks/useAccount";
import { useScaffoldReadContract } from "~~/hooks/scaffold-stark/useScaffoldReadContract";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-stark/useScaffoldWriteContract";
import { formatUnits, parseUnits } from "ethers";
import { toast } from "react-hot-toast";
import { UserAsset } from "./types";

export function WithdrawModal({
    asset,
    isOpen,
    onClose,
    onSuccess,
}: {
    asset: UserAsset;
    isOpen: boolean;
    onClose: () => void;
    onSuccess?: () => void;
}) {
    const [amount, setAmount] = useState("");
    const { address } = useAccount();

    // 获取最大可提款金额
    const { data: maxWithdraw } = useScaffoldReadContract({
        contractName: "LendingPool",
        functionName: "get_max_withdraw_amount",
        args: [address, asset.address],
    });

    const { sendAsync: withdraw, isPending } = useScaffoldWriteContract({
        contractName: "LendingPool",
        functionName: "withdraw",
        args: [asset.address, address, parseUnits(amount || "0", 18)],
    });

    const maxAmount = formatUnits(maxWithdraw?.toString() || "0", 18);

    const handleWithdraw = async () => {
        try {
            await withdraw({
                args: [asset.address, address, parseUnits(amount, 18)],
            });
            toast.success("Withdrawal successful!");
            onClose();
            onSuccess?.();
        } catch (error) {
            console.error("Withdrawal failed:", error);
            toast.error("Withdrawal failed");
        }
    };

    return (
        <dialog className={`modal ${isOpen ? "modal-open" : ""}`}>
            <div className="modal-box bg-base-200">
                <h3 className="font-bold text-lg mb-4 flex items-center gap-2">
                    <img
                        src={asset.icon}
                        alt={asset.symbol}
                        className="w-6 h-6"
                    />
                    Withdraw {asset.symbol}
                </h3>
                <div className="form-control">
                    <label className="label">
                        <span className="label-text">Amount</span>
                        <span className="label-text-alt">
                            Available: {maxAmount} {asset.symbol}
                        </span>
                    </label>
                    <input
                        type="number"
                        className="input input-bordered bg-base-300"
                        value={amount}
                        onChange={(e) => setAmount(e.target.value)}
                        max={maxAmount}
                        placeholder={`Enter amount to withdraw`}
                    />
                </div>
                <div className="modal-action">
                    <button
                        className="btn btn-ghost"
                        onClick={onClose}
                    >
                        Cancel
                    </button>
                    <button
                        className="btn btn-primary"
                        onClick={handleWithdraw}
                        disabled={isPending || !amount || Number(amount) <= 0}
                    >
                        {isPending ? <span className="loading loading-spinner" /> : "Withdraw"}
                    </button>
                </div>
            </div>
        </dialog>
    );
}
