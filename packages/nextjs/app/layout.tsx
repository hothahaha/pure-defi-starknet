import type { Metadata } from "next";
import { ScaffoldStarkAppWithProviders } from "~~/components/ScaffoldStarkAppWithProviders";
import "~~/styles/globals.css";
import { ThemeProvider } from "~~/components/ThemeProvider";
import { Markets } from "~~/components/market/Markets";

export const metadata: Metadata = {
    title: "Scaffold-Stark",
    description: "Fast track your starknet journey",
    icons: "/logo.ico",
};

const ScaffoldStarkApp = ({ children }: { children: React.ReactNode }) => {
    const menuLinks = [
        {
            label: "Markets",
            href: "/markets",
        },
        // ... 其他路由
    ];

    return (
        <html suppressHydrationWarning>
            <body>
                <ThemeProvider enableSystem>
                    <ScaffoldStarkAppWithProviders>{children}</ScaffoldStarkAppWithProviders>
                </ThemeProvider>
            </body>
        </html>
    );
};

export default ScaffoldStarkApp;
