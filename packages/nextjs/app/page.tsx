import Link from "next/link";
import { ConnectedAddress } from "~~/components/ConnectedAddress";

const Home = () => {
    return (
        <div className="flex flex-col flex-grow bg-base-200">
            <div className="container mx-auto max-w-7xl px-4 py-8">
                <h1 className="text-4xl font-bold mb-8">Pure DeFi</h1>

                <div className="tabs tabs-boxed bg-base-100 p-1 w-fit">
                    <Link
                        href="/markets"
                        className="tab"
                    >
                        Markets
                    </Link>
                    <Link
                        href="/admin"
                        className="tab"
                    >
                        Dashboard
                    </Link>
                    <Link
                        href="/asset-management"
                        className="tab"
                    >
                        Asset Management
                    </Link>
                </div>

                <div className="mt-8">
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                        {/* Markets Card */}
                        <Link
                            href="/markets"
                            className="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow"
                        >
                            <div className="card-body">
                                <h2 className="card-title">Markets</h2>
                                <p>View all available lending markets and their current rates</p>
                            </div>
                        </Link>

                        {/* Dashboard Card */}
                        <Link
                            href="/admin"
                            className="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow"
                        >
                            <div className="card-body">
                                <h2 className="card-title">Dashboard</h2>
                                <p>Manage your deposits, borrows and rewards</p>
                            </div>
                        </Link>

                        {/* Asset Management Card */}
                        <Link
                            href="/asset-management"
                            className="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow"
                        >
                            <div className="card-body">
                                <h2 className="card-title">Asset Management</h2>
                                <p>Configure and manage supported assets</p>
                            </div>
                        </Link>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Home;
