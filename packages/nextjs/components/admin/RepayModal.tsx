"use client";

import React, { useState } from "react";
import { Contract as StarknetJsContract } from "starknet";
import { useAccount } from "~~/hooks/useAccount";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-stark/useScaffoldWriteContract";
import { formatUnits, parseUnits } from "ethers";
import { toast } from "react-hot-toast";
import { UserAsset } from "./types";
import { useSendTransaction, useNetwork } from "@starknet-react/core";
import { useTargetNetwork } from "~~/hooks/scaffold-stark/useTargetNetwork";
import { useTransactor } from "~~/hooks/scaffold-stark/useTransactor";
import deployedContracts from "~~/contracts/deployedContracts";

// ERC20 ABI 只包含我们需要的 approve 方法
const ERC20_ABI = [
    {
        name: "approve",
        type: "function",
        inputs: [
            { name: "spender", type: "core::starknet::contract_address::ContractAddress" },
            { name: "amount", type: "core::integer::u256" },
        ],
        outputs: [],
        state_mutability: "external",
    },
] as const;

export function RepayModal({
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
    const [isApproving, setIsApproving] = useState(false);
    const sendTransactionInstance = useSendTransaction({});
    const { chain } = useNetwork();
    const { targetNetwork } = useTargetNetwork();
    const sendTxnWrapper = useTransactor();

    const { sendAsync: repay, isPending: isRepaying } = useScaffoldWriteContract({
        contractName: "LendingPool",
        functionName: "repay",
        args: [asset.address, address, parseUnits(amount || "0", 18)],
    });

    // 最大还款金额就是借款金额
    const maxAmount = asset.borrowAmount;

    const handleRepay = async () => {
        try {
            setIsApproving(true);

            // 检查网络状态
            if (!chain?.id) {
                throw new Error("Please connect your wallet");
            }
            if (chain?.id !== targetNetwork.id) {
                throw new Error("You are on the wrong network");
            }

            // 创建 ERC20 合约实例
            const erc20Contract = new StarknetJsContract(ERC20_ABI, asset.address);

            // 构建 approve 调用
            const approveCall = [
                erc20Contract.populate("approve", [
                    deployedContracts[targetNetwork.network as keyof typeof deployedContracts]
                        .LendingPool.address,
                    parseUnits(amount, 18),
                ]),
            ];

            // 使用 sendTxnWrapper 包装 approve 交易
            await sendTxnWrapper(() => sendTransactionInstance.sendAsync(approveCall));

            // approve 完成后执行 repay
            await repay({
                args: [asset.address, address, parseUnits(amount, 18)],
            });

            toast.success("Repayment successful!");
            onClose();
            onSuccess?.();
        } catch (error: any) {
            console.error("Transaction failed:", error);
            if (error?.message?.includes("User abort")) {
                toast.error("Transaction cancelled by user");
            } else if (error?.message?.includes("insufficient funds")) {
                toast.error("Insufficient funds");
            } else {
                toast.error(error.message || "Transaction failed");
            }
        } finally {
            setIsApproving(false);
        }
    };

    const isPending = isApproving || isRepaying;

    return (
        <dialog className={`modal ${isOpen ? "modal-open" : ""}`}>
            <div className="modal-box bg-base-200">
                <h3 className="font-bold text-lg mb-4 flex items-center gap-2">
                    <img
                        src={asset.icon}
                        alt={asset.symbol}
                        className="w-6 h-6"
                    />
                    Repay {asset.symbol}
                </h3>
                <div className="form-control">
                    <label className="label">
                        <span className="label-text">Amount</span>
                        <span className="label-text-alt">
                            Borrowed: {maxAmount} {asset.symbol}
                        </span>
                    </label>
                    <input
                        type="number"
                        className="input input-bordered bg-base-300"
                        value={amount}
                        onChange={(e) => setAmount(e.target.value)}
                        max={maxAmount}
                        placeholder={`Enter amount to repay`}
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
                        onClick={handleRepay}
                        disabled={isPending || !amount || Number(amount) <= 0}
                    >
                        {isPending ? <span className="loading loading-spinner" /> : "Repay"}
                    </button>
                </div>
            </div>
        </dialog>
    );
}
