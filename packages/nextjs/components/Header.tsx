"use client";

import React, { useCallback, useRef, useState, useEffect } from "react";
import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Bars3Icon, BugAntIcon } from "@heroicons/react/24/outline";
import { useOutsideClick } from "~~/hooks/scaffold-stark";
import { CustomConnectButton } from "~~/components/scaffold-stark/CustomConnectButton";
import { useTheme } from "next-themes";
import { useTargetNetwork } from "~~/hooks/scaffold-stark/useTargetNetwork";
import { devnet } from "@starknet-react/chains";
import { SwitchTheme } from "./SwitchTheme";
import { useAccount, useNetwork, useProvider } from "@starknet-react/core";
import { BlockIdentifier } from "starknet";

type HeaderMenuLink = {
    label: string;
    href: string;
    icon?: React.ReactNode;
};

export const menuLinks: HeaderMenuLink[] = [
    {
        label: "Markets",
        href: "/markets",
    },
    {
        label: "Dashboard",
        href: "/admin",
    },
    {
        label: "Asset Management",
        href: "/asset-management",
    },
    {
        label: "Debug Contracts",
        href: "/debug",
        icon: <BugAntIcon className="h-4 w-4" />,
    },
];

export const HeaderMenuLinks = () => {
    const pathname = usePathname();
    const { theme } = useTheme();
    const [isDark, setIsDark] = useState(false);

    useEffect(() => {
        setIsDark(theme === "dark");
    }, [theme]);

    return (
        <>
            {menuLinks.map(({ label, href, icon }) => {
                const isActive = pathname === href;
                return (
                    <li key={href}>
                        <Link
                            href={href}
                            passHref
                            className={`${
                                isActive ? "bg-secondary text-secondary-content" : ""
                            } hover:bg-secondary hover:text-secondary-content gap-2 py-2 px-4 rounded-xl`}
                        >
                            {icon}
                            <span>{label}</span>
                        </Link>
                    </li>
                );
            })}
        </>
    );
};

/**
 * Site header
 */
export const Header = () => {
    const [isDrawerOpen, setIsDrawerOpen] = useState(false);
    const burgerMenuRef = useRef<HTMLDivElement>(null);
    useOutsideClick(
        burgerMenuRef,
        useCallback(() => setIsDrawerOpen(false), [])
    );

    return (
        <div className="sticky top-0 navbar bg-base-100 min-h-0 flex-shrink-0 justify-between z-20 shadow-md shadow-secondary px-0 sm:px-2">
            <div className="navbar-start w-auto lg:w-1/2">
                <div
                    className="lg:hidden dropdown"
                    ref={burgerMenuRef}
                >
                    <label
                        tabIndex={0}
                        className={`ml-1 btn btn-ghost ${isDrawerOpen ? "hover:bg-secondary" : "hover:bg-transparent"}`}
                        onClick={() => {
                            setIsDrawerOpen((prevIsOpenState) => !prevIsOpenState);
                        }}
                    >
                        <Bars3Icon className="h-1/2" />
                    </label>
                    {isDrawerOpen && (
                        <ul
                            tabIndex={0}
                            className="menu menu-compact dropdown-content mt-3 p-2 shadow bg-base-100 rounded-box w-52"
                            onClick={() => {
                                setIsDrawerOpen(false);
                            }}
                        >
                            <HeaderMenuLinks />
                        </ul>
                    )}
                </div>
                <Link
                    href="/"
                    passHref
                    className="hidden lg:flex items-center gap-2 ml-4 mr-6 shrink-0"
                >
                    <div className="flex relative w-10 h-10">
                        <Image
                            alt="Pure DeFi logo"
                            className="cursor-pointer"
                            fill
                            src="/logo.svg"
                        />
                    </div>
                    <div className="flex flex-col">
                        <span className="font-bold leading-tight">Pure DeFi</span>
                        <span className="text-xs">Lending Protocol</span>
                    </div>
                </Link>
                <ul className="hidden lg:flex lg:flex-nowrap menu menu-horizontal gap-2 px-1">
                    <HeaderMenuLinks />
                </ul>
            </div>
            <div className="navbar-end flex-grow mr-4">
                <CustomConnectButton />
                <SwitchTheme />
            </div>
        </div>
    );
};
