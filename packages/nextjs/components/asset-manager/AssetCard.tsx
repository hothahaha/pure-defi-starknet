import { formatUnits } from "ethers";
import { AssetCardProps } from "./types";
import { useMemo } from "react";

function formatLargeNumber(value: string): string {
    const num = Number(value);
    if (num >= 1_000_000) {
        return `${(num / 1_000_000).toFixed(2)}M`;
    } else if (num >= 1_000) {
        return `${(num / 1_000).toFixed(2)}K`;
    }
    return num.toFixed(2);
}

export function AssetCard({ asset, onEdit }: AssetCardProps) {
    const formattedDeposits = useMemo(
        () => formatLargeNumber(asset.totalDeposits),
        [asset.totalDeposits]
    );
    const formattedBorrows = useMemo(
        () => formatLargeNumber(asset.totalBorrows),
        [asset.totalBorrows]
    );

    return useMemo(
        () => (
            <div className="card bg-base-100 shadow-xl hover:shadow-2xl transition-all duration-200">
                <div className="card-body">
                    <div className="flex items-center gap-4 mb-4">
                        <img
                            src={asset.icon}
                            alt={asset.symbol}
                            className="w-12 h-12 rounded-full shadow-md"
                        />
                        <div>
                            <h3 className="card-title text-xl">{asset.symbol}</h3>
                            <p className="text-sm opacity-70">{asset.name}</p>
                        </div>
                    </div>

                    <div className="stats bg-base-300 shadow-lg mb-4">
                        <div className="stat p-4">
                            <div className="stat-title text-lg font-medium mb-2">
                                Total Deposits
                            </div>
                            <div className="stat-value text-2xl md:text-3xl text-red-500">
                                {formattedDeposits}
                            </div>
                        </div>
                        <div className="stat p-4">
                            <div className="stat-title text-lg font-medium mb-2">Total Borrows</div>
                            <div className="stat-value text-2xl md:text-3xl text-green-500">
                                {formattedBorrows}
                            </div>
                        </div>
                    </div>

                    <div className="grid grid-cols-2 gap-4 bg-base-200 rounded-lg p-4">
                        <div>
                            <div className="text-sm opacity-70">Collateral Factor</div>
                            <div className="text-lg font-semibold">
                                {(Number(asset.collateralFactor) * 100).toFixed(0)}%
                            </div>
                        </div>
                        <div>
                            <div className="text-sm opacity-70">Borrow Factor</div>
                            <div className="text-lg font-semibold">
                                {(Number(asset.borrowFactor) * 100).toFixed(0)}%
                            </div>
                        </div>
                    </div>

                    <div className="card-actions justify-end mt-4">
                        <button
                            className="btn btn-primary btn-sm"
                            onClick={() => onEdit(asset)}
                        >
                            Edit Asset
                        </button>
                    </div>
                </div>
            </div>
        ),
        [asset, formattedDeposits, formattedBorrows, onEdit]
    );
}
