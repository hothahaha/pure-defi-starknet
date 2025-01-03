import { MarketStatsProps } from "./types";

export function MarketStats({ totalDeposits, totalBorrows }: MarketStatsProps) {
    return (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 w-full">
            <div className="stat bg-base-100 rounded-box shadow">
                <div className="stat-title text-base-content/60">Total Deposits</div>
                <div className="stat-value text-3xl">${totalDeposits}</div>
            </div>

            <div className="stat bg-base-100 rounded-box shadow">
                <div className="stat-title text-base-content/60">Total Borrows</div>
                <div className="stat-value text-3xl">${totalBorrows}</div>
            </div>
        </div>
    );
}
