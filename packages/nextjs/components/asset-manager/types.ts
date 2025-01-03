import { Address } from "@starknet-react/chains";

export interface Asset {
    address: string;
    symbol: string;
    name: string;
    decimals: string;
    pairId: string;
    icon: string;
    isSupported: boolean;
    collateralFactor: string;
    borrowFactor: string;
    totalDeposits: string;
    totalBorrows: string;
}

export interface AssetFormData {
    address: string;
    symbol: string;
    name: string;
    decimals?: string;
    icon: string;
    isSupported: boolean;
    collateralFactor: string;
    borrowFactor: string;
}

export interface AssetCardProps {
    asset: Asset;
    onEdit: (asset: Asset) => void;
}

export interface AssetFormProps {
    asset: Asset;
    onClose: () => void;
    onSubmit: (data: AssetFormData) => void;
    onRefresh: () => void;
    initialData?: Asset;
    isEdit?: boolean;
}
