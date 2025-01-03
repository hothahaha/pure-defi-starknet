import { Markets } from "~~/components/market/Markets";
import type { NextPage } from "next";
import { getMetadata } from "~~/utils/scaffold-stark/getMetadata";

export const metadata = getMetadata({
    title: "Markets",
    description: "Pure DeFi lending markets",
});

const MarketsPage: NextPage = () => {
    return <Markets />;
};

export default MarketsPage;
