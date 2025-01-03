import { Address } from "@starknet-react/chains";

export interface Market {
    address: string;
    symbol: string;
    name: string;
    icon: string;
    depositAPY: string;
    borrowAPY: string;
    asset_price: string;
    walletBalance: string;
    depositBalance: string;
    borrowBalance: string;
}

export interface MarketCardProps {
    market: Market;
    isConnected: boolean;
    onRefresh: () => Promise<void>;
}

export interface MarketStatsProps {
    totalDeposits: string;
    totalBorrows: string;
}
