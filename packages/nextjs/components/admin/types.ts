export interface UserAsset {
    address: string;
    symbol: string;
    name: string;
    icon: string;
    depositAmount: string;
    borrowAmount: string;
    depositValue: string;
    borrowValue: string;
    pendingRewards: string;
}

export interface UserStats {
    totalDepositValue: string;
    totalBorrowValue: string;
    healthFactor: string;
}
