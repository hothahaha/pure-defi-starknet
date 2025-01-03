export function UserStats({ totalValue }: { totalValue: string }) {
    return (
        <div className="stats shadow w-full bg-base-100">
            <div className="stat">
                <div className="stat-title">Total Value</div>
                <div className="stat-value">${totalValue}</div>
            </div>
        </div>
    );
}
