export function UserStats({
    totalDeposit,
    totalBorrow,
}: {
    totalDeposit: string;
    totalBorrow: string;
}) {
    return (
        <div className="stats shadow w-full bg-base-100">
            <div className="stat">
                <div className="stat-title">Total Deposit</div>
                <div className="stat-value">${totalDeposit}</div>
            </div>
            <div className="stat">
                <div className="stat-title">Total Borrow</div>
                <div className="stat-value text-warning">${totalBorrow}</div>
            </div>
        </div>
    );
}
