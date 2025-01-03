use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockERC20STRK<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn approve_token(ref self: TContractState, spender: ContractAddress, amount: u256);
}

#[starknet::contract]
mod MockERC20STRK {
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        let name = "STRK";
        let symbol = "STRK";
        self.erc20.initializer(name, symbol);
    }

    #[abi(embed_v0)]
    impl MockERC20STRKImpl of super::IMockERC20STRK<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.erc20.mint(to, amount);
        }

        fn approve_token(ref self: ContractState, spender: ContractAddress, amount: u256) {
            self.erc20.approve(spender, amount);
        }
    }
}
