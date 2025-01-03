import { Admin } from "~~/components/admin/Admin";
import type { NextPage } from "next";
import { getMetadata } from "~~/utils/scaffold-stark/getMetadata";

export const metadata = getMetadata({
    title: "Admin",
    description: "User dashboard for Pure DeFi",
});

const AdminPage: NextPage = () => {
    return <Admin />;
};

export default AdminPage;
