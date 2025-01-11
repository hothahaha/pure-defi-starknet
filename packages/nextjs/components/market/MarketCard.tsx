"use client";

import { useState, useCallback } from "react";
import { Contract as StarknetJsContract } from "starknet";
import { useAccount } from "~~/hooks/useAccount";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-stark/useScaffoldWriteContract";
import { useScaffoldReadContract } from "~~/hooks/scaffold-stark/useScaffoldReadContract";
import { formatUnits, parseUnits } from "ethers";
import { toast } from "react-hot-toast";
import { Market, MarketCardProps } from "./types";
import { createPortal } from "react-dom";
import deployedContracts from "~~/contracts/deployedContracts";
import { useSendTransaction, useNetwork } from "@starknet-react/core";
import { useTargetNetwork } from "~~/hooks/scaffold-stark/useTargetNetwork";
import { useTransactor } from "~~/hooks/scaffold-stark/useTransactor";

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

function DepositModal({
    market,
    isOpen,
    onClose,
    onSuccess,
}: {
    market: Market;
    isOpen: boolean;
    onClose: () => void;
    onSuccess?: () => void;
}) {
    const sendTransactionInstance = useSendTransaction({});
    const [amount, setAmount] = useState("");
    const { address } = useAccount();
    const [isApproving, setIsApproving] = useState(false);
    const { chain } = useNetwork();
    const { targetNetwork } = useTargetNetwork();
    const sendTxnWrapper = useTransactor();

    const { sendAsync: deposit, isPending: isDepositing } = useScaffoldWriteContract({
        contractName: "LendingPool",
        functionName: "deposit",
        args: [market.address, address, parseUnits(amount || "0", 18)],
    });

    const handleDeposit = async () => {
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
            const erc20Contract = new StarknetJsContract(ERC20_ABI, market.address);

            console.log("targetNetwork.network: ", targetNetwork.network);
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

            // approve 完成后执行 deposit
            await deposit({
                args: [market.address, address, parseUnits(amount, 18)],
            });

            toast.success("Deposit successful!");
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

    const isPending = isApproving || isDepositing;

    return (
        <dialog className={`modal ${isOpen ? "modal-open" : ""}`}>
            <div className="modal-box bg-base-200">
                <h3 className="font-bold text-lg mb-4 flex items-center gap-2">
                    <img
                        src={market.icon}
                        alt={market.symbol}
                        className="w-6 h-6"
                    />
                    Deposit {market.symbol}
                </h3>
                <div className="form-control">
                    <label className="label">
                        <span className="label-text">Amount</span>
                        <span className="label-text-alt">
                            Available: {market.walletBalance} {market.symbol}
                        </span>
                    </label>
                    <input
                        type="number"
                        className="input input-bordered bg-base-300"
                        value={amount}
                        onChange={(e) => setAmount(e.target.value)}
                        max={market.walletBalance}
                        placeholder={`Enter amount to deposit`}
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
                        onClick={handleDeposit}
                        disabled={isPending || !amount || Number(amount) <= 0}
                    >
                        {isPending ? <span className="loading loading-spinner" /> : "Deposit"}
                    </button>
                </div>
            </div>
        </dialog>
    );
}

function BorrowModal({
    market,
    isOpen,
    onClose,
    onSuccess,
}: {
    market: Market;
    isOpen: boolean;
    onClose: () => void;
    onSuccess?: () => void;
}) {
    const [amount, setAmount] = useState("");
    const { address, isConnected } = useAccount();
    const { data: borrowLimit } = useScaffoldReadContract({
        contractName: "LendingPool",
        functionName: "get_user_borrow_limit",
        args: [address, market.address],
    });

    const { sendAsync: borrow, isPending: isBorrowing } = useScaffoldWriteContract({
        contractName: "LendingPool",
        functionName: "borrow",
        args: [market.address, address, parseUnits(amount || "0", 18)],
    });

    const maxBorrowAmount = formatUnits(borrowLimit?.toString() || "0", 18);

    const handleBorrow = async () => {
        try {
            await borrow({
                args: [market.address, address, parseUnits(amount, 18)],
            });
            toast.success("Borrow successful!");
            onClose();
            onSuccess?.();
        } catch (error) {
            console.error("Borrow failed:", error);
            toast.error("Borrow failed");
        }
    };

    return (
        <dialog className={`modal ${isOpen ? "modal-open" : ""}`}>
            <div className="modal-box bg-base-200">
                <h3 className="font-bold text-lg mb-4 flex items-center gap-2">
                    <img
                        src={market.icon}
                        alt={market.symbol}
                        className="w-6 h-6"
                    />
                    Borrow {market.symbol}
                </h3>
                <div className="form-control">
                    <label className="label">
                        <span className="label-text">Amount</span>
                        <span className="label-text-alt">
                            Available: {maxBorrowAmount} {market.symbol}
                        </span>
                    </label>
                    <input
                        type="number"
                        className="input input-bordered bg-base-300"
                        value={amount}
                        onChange={(e) => setAmount(e.target.value)}
                        max={maxBorrowAmount}
                        placeholder={`Enter amount to borrow`}
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
                        onClick={handleBorrow}
                        disabled={isBorrowing || !amount || Number(amount) <= 0}
                    >
                        {isBorrowing ? <span className="loading loading-spinner" /> : "Borrow"}
                    </button>
                </div>
            </div>
        </dialog>
    );
}

export function MarketCard({ market, isConnected, onRefresh }: MarketCardProps) {
    const [isDepositModalOpen, setIsDepositModalOpen] = useState(false);
    const [isBorrowModalOpen, setIsBorrowModalOpen] = useState(false);

    return (
        <>
            <tr className="hover:bg-base-300 transition-colors">
                <td className="font-medium flex items-center gap-2">
                    <img
                        src={market.icon}
                        alt={market.symbol}
                        className="w-8 h-8"
                    />
                    {market.symbol}
                </td>
                <td className="font-mono">${Number(market.asset_price).toFixed(4)}</td>
                <td className="text-success font-mono">{Number(market.depositAPY).toFixed(4)}%</td>
                <td className="text-warning font-mono">{Number(market.borrowAPY).toFixed(4)}%</td>
                <td className="font-mono">{market.walletBalance}</td>
                {isConnected && (
                    <>
                        <td className="font-mono">{market.depositBalance}</td>
                        <td className="font-mono">{market.borrowBalance}</td>
                    </>
                )}
                <td>
                    <div className="flex gap-2">
                        <button
                            className="btn btn-sm btn-primary"
                            onClick={() => setIsDepositModalOpen(true)}
                            disabled={!isConnected || Number(market.walletBalance) <= 0}
                        >
                            Deposit
                        </button>
                        <button
                            className="btn btn-sm btn-secondary"
                            onClick={() => setIsBorrowModalOpen(true)}
                            disabled={!isConnected}
                        >
                            Borrow
                        </button>
                    </div>
                </td>
            </tr>

            {createPortal(
                <>
                    {isDepositModalOpen && (
                        <DepositModal
                            market={market}
                            isOpen={isDepositModalOpen}
                            onClose={() => setIsDepositModalOpen(false)}
                            onSuccess={onRefresh}
                        />
                    )}
                    {isBorrowModalOpen && (
                        <BorrowModal
                            market={market}
                            isOpen={isBorrowModalOpen}
                            onClose={() => setIsBorrowModalOpen(false)}
                            onSuccess={onRefresh}
                        />
                    )}
                </>,
                document.body
            )}
        </>
    );
}
