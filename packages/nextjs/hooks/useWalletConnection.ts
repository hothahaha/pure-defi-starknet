import { useEffect } from "react";
import { useAccount, useConnect, useDisconnect } from "@starknet-react/core";

export function useWalletConnection() {
    const { address, isConnected, connector } = useAccount();
    const { connect, connectors } = useConnect();
    const { disconnect } = useDisconnect();

    useEffect(() => {
        // 从 localStorage 获取上次连接的钱包信息
        const lastConnector = window.localStorage.getItem("lastConnector");

        // 如果未连接但有上次连接记录，尝试重新连接
        if (!isConnected && lastConnector) {
            const connector = connectors.find((c) => c.id === lastConnector);
            if (connector) {
                connect({ connector });
            }
        }
    }, [isConnected, connect, connectors]);

    useEffect(() => {
        // 连接成功后保存连接信息
        if (isConnected && connector) {
            window.localStorage.setItem("lastConnector", connector.id);
        }
    }, [isConnected, connector]);

    // 扩展断开连接功能
    const handleDisconnect = async () => {
        try {
            await disconnect();
            // 清除本地存储的连接信息
            window.localStorage.removeItem("lastConnector");
        } catch (error) {
            console.error("Failed to disconnect:", error);
        }
    };

    return {
        address,
        isConnected,
        disconnect: handleDisconnect, // 返回新的断开连接函数
    };
}
