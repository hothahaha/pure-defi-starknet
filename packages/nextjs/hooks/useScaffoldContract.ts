import { useCallback } from "react";
import { toast } from "react-hot-toast";

export function useScaffoldContract() {
    const handleContractError = useCallback((error: any) => {
        console.error("Contract error:", error);
        if (error?.message?.includes("User abort")) {
            toast.error("Transaction cancelled by user");
        } else if (error?.message?.includes("insufficient funds")) {
            toast.error("Insufficient funds");
        } else {
            toast.error("Transaction failed. Please try again.");
        }
    }, []);

    return { handleContractError };
}
