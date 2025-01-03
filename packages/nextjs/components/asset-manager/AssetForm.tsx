import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { AssetFormData, AssetFormProps } from "./types";
import { AddressInput } from "~~/components/scaffold-stark";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-stark/useScaffoldWriteContract";
import { parseUnits } from "ethers";
import { toast } from "react-hot-toast";

export function AssetForm({ asset, onClose, onRefresh }: AssetFormProps) {
    const [address, setAddress] = useState(asset?.address || "");
    const [symbol, setSymbol] = useState(asset?.symbol || "");
    const [name, setName] = useState(asset?.name || "");
    const [decimals, setDecimals] = useState(asset?.decimals || "18");
    const [pairId, setPairId] = useState(asset?.pairId || "");
    const [collateralFactor, setCollateralFactor] = useState(
        asset ? String(Number(asset.collateralFactor) * 100) : "80"
    );
    const [borrowFactor, setBorrowFactor] = useState(
        asset ? String(Number(asset.borrowFactor) * 100) : "80"
    );
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [icon, setIcon] = useState(asset?.icon || "");
    const [isSupported, setIsSupported] = useState(asset?.isSupported ?? true);

    const {
        register,
        formState: { errors },
        setError,
        clearErrors,
    } = useForm<AssetFormData>();

    const validatePercentage = (value: string, field: string) => {
        const num = Number(value);
        if (isNaN(num) || num < 1 || num > 100) {
            setError(field as any, {
                type: "manual",
                message: "Value must be between 1 and 100",
            });
            return false;
        }
        clearErrors(field as any);
        return true;
    };

    // 初始化合约写入函数
    const { sendAsync } = useScaffoldWriteContract({
        contractName: asset ? "AssetManager" : "LendingPool",
        functionName: asset ? "update_asset" : "add_asset",
        args: [address, {}],
    });

    const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        if (!address) {
            setError("address", { type: "manual", message: "Address is required" });
            return;
        }

        if (
            !validatePercentage(collateralFactor, "collateralFactor") ||
            !validatePercentage(borrowFactor, "borrowFactor")
        ) {
            return;
        }

        setIsSubmitting(true);

        try {
            const assetConfig = {
                is_supported: isSupported,
                symbol,
                name,
                decimals: Number(decimals),
                pair_id: pairId,
                collateral_factor: parseUnits(String(Number(collateralFactor) / 100), 18),
                borrow_factor: parseUnits(String(Number(borrowFactor) / 100), 18),
                icon,
            };

            // 发送交易并在回调中处理所有后续操作
            await sendAsync({
                args: [address, assetConfig],
            });
            onRefresh();
            onClose();
        } catch (error) {
            console.error("Transaction failed:", error);
            toast.error("Failed to submit transaction");
        } finally {
            setIsSubmitting(false);
        }
    };

    return (
        <dialog
            className="modal modal-open"
            onClose={onClose}
        >
            <div className="modal-box bg-base-200">
                <h3 className="font-bold text-lg mb-4">{asset ? "Edit Asset" : "Add Asset"}</h3>
                <form
                    onSubmit={handleSubmit}
                    className="space-y-4"
                >
                    <div className="form-control">
                        <label className="label">
                            <span className="label-text">Asset Address</span>
                        </label>
                        <AddressInput
                            name="address"
                            placeholder="Enter asset address"
                            value={address}
                            onChange={setAddress}
                            disabled={Boolean(asset)}
                        />
                        {errors.address && (
                            <span className="text-error text-sm">{errors.address.message}</span>
                        )}
                    </div>

                    <div className="form-control">
                        <label className="label">
                            <span className="label-text">Symbol</span>
                        </label>
                        <input
                            type="text"
                            className="input input-bordered bg-base-300"
                            value={symbol}
                            onChange={(e) => setSymbol(e.target.value)}
                            placeholder="Enter symbol"
                            required
                        />
                    </div>

                    <div className="form-control">
                        <label className="label">
                            <span className="label-text">Name</span>
                        </label>
                        <input
                            type="text"
                            className="input input-bordered bg-base-300"
                            value={name}
                            onChange={(e) => setName(e.target.value)}
                            placeholder="Enter name"
                            required
                        />
                    </div>

                    <div className="form-control">
                        <label className="label">
                            <span className="label-text">Pair ID</span>
                        </label>
                        <input
                            type="text"
                            className="input input-bordered bg-base-300"
                            value={pairId}
                            onChange={(e) => setPairId(e.target.value)}
                            placeholder="Enter pair ID"
                            required
                        />
                    </div>

                    <div className="form-control">
                        <label className="label">
                            <span className="label-text">Decimals</span>
                        </label>
                        <input
                            type="number"
                            className="input input-bordered bg-base-300"
                            value={decimals}
                            onChange={(e) => setDecimals(e.target.value)}
                            placeholder="Enter decimals"
                            required
                        />
                    </div>

                    <div className="form-control">
                        <label className="label">
                            <span className="label-text">Collateral Factor (%)</span>
                        </label>
                        <input
                            type="number"
                            className="input input-bordered bg-base-300"
                            value={collateralFactor}
                            onChange={(e) => setCollateralFactor(e.target.value)}
                            placeholder="Enter value between 1-100"
                            min="1"
                            max="100"
                            required
                        />
                        {errors.collateralFactor && (
                            <span className="text-error text-sm">
                                {errors.collateralFactor.message}
                            </span>
                        )}
                    </div>

                    <div className="form-control">
                        <label className="label">
                            <span className="label-text">Borrow Factor (%)</span>
                        </label>
                        <input
                            type="number"
                            className="input input-bordered bg-base-300"
                            value={borrowFactor}
                            onChange={(e) => setBorrowFactor(e.target.value)}
                            placeholder="Enter value between 1-100"
                            min="1"
                            max="100"
                            required
                        />
                        {errors.borrowFactor && (
                            <span className="text-error text-sm">
                                {errors.borrowFactor.message}
                            </span>
                        )}
                    </div>

                    <div className="form-control">
                        <label className="label">
                            <span className="label-text">Icon URL</span>
                        </label>
                        <input
                            type="text"
                            className="input input-bordered bg-base-300"
                            value={icon}
                            onChange={(e) => setIcon(e.target.value)}
                            placeholder="Enter icon URL"
                        />
                    </div>

                    <div className="form-control">
                        <label className="label cursor-pointer">
                            <span className="label-text">Is Supported</span>
                            <input
                                type="checkbox"
                                className="toggle toggle-success"
                                checked={isSupported}
                                onChange={(e) => setIsSupported(e.target.checked)}
                            />
                        </label>
                    </div>

                    <div className="modal-action">
                        <button
                            type="button"
                            className="btn btn-ghost"
                            onClick={onClose}
                            disabled={isSubmitting}
                        >
                            Cancel
                        </button>
                        <button
                            type="submit"
                            className="btn btn-primary"
                            disabled={isSubmitting}
                        >
                            {isSubmitting ? (
                                <span className="loading loading-spinner"></span>
                            ) : asset ? (
                                "Update"
                            ) : (
                                "Add"
                            )}
                        </button>
                    </div>
                </form>
            </div>
        </dialog>
    );
}
