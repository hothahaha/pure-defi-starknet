export const ERC20_ABI = [
    {
        type: "impl",
        name: "ERC20Impl",
        interface_name: "openzeppelin_token::erc20::interface::IERC20Mixin",
    },
    {
        type: "struct",
        name: "core::integer::u256",
        members: [
            { name: "low", type: "core::integer::u128" },
            { name: "high", type: "core::integer::u128" },
        ],
    },
    {
        type: "interface",
        name: "openzeppelin_token::erc20::interface::IERC20Mixin",
        items: [
            {
                type: "function",
                name: "name",
                inputs: [],
                outputs: [{ type: "core::felt252" }],
                state_mutability: "view",
            },
            {
                type: "function",
                name: "symbol",
                inputs: [],
                outputs: [{ type: "core::felt252" }],
                state_mutability: "view",
            },
            {
                type: "function",
                name: "decimals",
                inputs: [],
                outputs: [{ type: "core::integer::u8" }],
                state_mutability: "view",
            },
            {
                type: "function",
                name: "total_supply",
                inputs: [],
                outputs: [{ type: "core::integer::u256" }],
                state_mutability: "view",
            },
            {
                type: "function",
                name: "balance_of",
                inputs: [
                    { name: "account", type: "core::starknet::contract_address::ContractAddress" },
                ],
                outputs: [{ type: "core::integer::u256" }],
                state_mutability: "view",
            },
            {
                type: "function",
                name: "allowance",
                inputs: [
                    { name: "owner", type: "core::starknet::contract_address::ContractAddress" },
                    { name: "spender", type: "core::starknet::contract_address::ContractAddress" },
                ],
                outputs: [{ type: "core::integer::u256" }],
                state_mutability: "view",
            },
            {
                type: "function",
                name: "transfer",
                inputs: [
                    {
                        name: "recipient",
                        type: "core::starknet::contract_address::ContractAddress",
                    },
                    { name: "amount", type: "core::integer::u256" },
                ],
                outputs: [],
                state_mutability: "external",
            },
            {
                type: "function",
                name: "transfer_from",
                inputs: [
                    { name: "sender", type: "core::starknet::contract_address::ContractAddress" },
                    {
                        name: "recipient",
                        type: "core::starknet::contract_address::ContractAddress",
                    },
                    { name: "amount", type: "core::integer::u256" },
                ],
                outputs: [],
                state_mutability: "external",
            },
            {
                type: "function",
                name: "approve",
                inputs: [
                    { name: "spender", type: "core::starknet::contract_address::ContractAddress" },
                    { name: "amount", type: "core::integer::u256" },
                ],
                outputs: [],
                state_mutability: "external",
            },
        ],
    },
];
