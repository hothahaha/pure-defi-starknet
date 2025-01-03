use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq, Debug, starknet::Store)]
pub struct DailyMint {
    pub amount: u256,
    pub timestamp: u64,
    pub processed: bool,
}

#[starknet::interface]
pub trait IDSC<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn burn(ref self: TContractState, amount: u256);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn update_minter(ref self: TContractState, minter: ContractAddress, status: bool);
    fn balance_of(ref self: TContractState, account: ContractAddress) -> u256;
}

#[starknet::contract]
pub mod DSCToken {
    use OwnableComponent::InternalTrait;
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_security::pausable::PausableComponent;

    use core::num::traits::{Zero};
    use super::{ContractAddress, DailyMint, IDSC};
    use starknet::{get_caller_address};
    use starknet::storage::{Map, StorageMapWriteAccess, StoragePathEntry};
    use starknet::storage::{StoragePointerReadAccess};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    const DAILY_SECONDS: u64 = 86400; // 1 days
    const INITIAL_DAILY_LIMIT: u256 = 100_000_000_000_000; // 1_000_000 * 1e18
    const MAX_DAILY_LIMIT: u256 = 1_000_000_000_000_000; // 10_000_000 * 1e18

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        minters: Map<ContractAddress, bool>,
        daily_mints: Map<u64, DailyMint>,
        daily_mint_amount: Map<u64, u256>,
        daily_mint_limit: u256,
        paused: bool,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        MinterStatusChanged: MinterStatusChanged,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct MinterStatusChanged {
        #[key]
        minter: ContractAddress,
        status: bool,
    }

    pub mod Errors {
        pub const NOT_MINTER: felt252 = 'DSC: not minter';
        pub const DAILY_LIMIT_EXCEEDED: felt252 = 'DSC: daily limit exceeded';
        pub const INVALID_AMOUNT: felt252 = 'DSC: invalid amount';
        pub const ALREADY_MINTER: felt252 = 'DSC: already minter';
        pub const INVALID_MINTER: felt252 = 'DSC: invalid minter';
        pub const INVALID_DAILY_LIMIT: felt252 = 'DSC: invalid daily limit';
        pub const PAUSED: felt252 = 'DSC: paused';
        pub const ZERO_ADDRESS: felt252 = 'DSC: zero address';
        pub const INSUFFICIENT_ALLOWANCE: felt252 = 'DSC: insufficient allowance';
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        let name = "DSC Token";
        let symbol = "DSC";
        self.erc20.initializer(name, symbol);
    }

    #[abi(embed_v0)]
    impl DSCImpl of IDSC<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            self.pausable.assert_not_paused();

            let caller = get_caller_address();
            assert(self.minters.entry(caller).read(), Errors::NOT_MINTER);

            self.erc20.mint(to, amount.into());
            true
        }

        fn burn(ref self: ContractState, amount: u256) {
            self.pausable.assert_not_paused();
            self.erc20.burn(get_caller_address(), amount.into());
        }

        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.pause();
        }

        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.unpause();
        }

        fn update_minter(ref self: ContractState, minter: ContractAddress, status: bool) {
            self.ownable.assert_only_owner();
            assert(!minter.is_zero(), Errors::INVALID_MINTER);

            self.minters.write(minter, status);
            self.emit(MinterStatusChanged { minter, status });
        }

        fn balance_of(ref self: ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }
    }
}

