use starknet::{ContractAddress, get_block_timestamp, get_block_number, get_contract_address};
use super::utils::time_weighted_rewards_utils::{calculate_weighted_amount};
use super::asset_manager::{IAssetManagerDispatcher, AssetConfig};
use super::dsc_token::{IDSCDispatcher};
use super::utils::interest_rate_model_utils::{interest_rate_model_utils};
use super::pragma_custom::{IPragmaCustomDispatcher, IPragmaCustomDispatcherTrait};
use starknet::storage::{Map, StorageMapWriteAccess, StoragePathEntry};

#[derive(Copy, Drop, Serde)]
struct PragmaPricesResponse {
    price: u128,
    decimals: u32,
    last_updated_timestamp: u64,
    num_sources_aggregated: u32,
}

#[derive(Copy, Drop, Serde, PartialEq, Debug, starknet::Store)]
pub struct UserInfo {
    pub deposit_amount: u256, // 用户存款金额
    pub borrow_amount: u256, // 用户借款金额
    pub last_update_time: u64, // 最后更新时间
    pub reward_debt: u256, // 奖励债务
    pub borrow_index: u256, // 用户借款指数
    pub deposit_index: u256, // 用户存款指数
    pub deposit_amount_usd: u256, // 用户存款金额美元
    pub borrow_amount_usd: u256 // 用户借款金额美元
}

#[derive(Copy, Drop, Serde, PartialEq, Debug, starknet::Store)]
pub struct AssetInfo {
    pub total_deposits: u256, // 总存款
    pub total_borrows: u256, // 总借款
    pub last_update_time: u64, // 最后更新时间
    pub current_rate: u256, // 当前利率
    pub borrow_rate: u256, // 借款利率
    pub deposit_rate: u256, // 存款利率
    pub reserve_factor: u256, // 储备金率
    pub borrow_index: u256, // 借款指数
    pub deposit_index: u256, // 存款指数
    pub user_balance: u256, // 用户余额
    pub asset_price: u128, // 资产价格
    pub total_deposits_usd: u256, // 总存款美元
    pub total_borrows_usd: u256 // 总借款美元
}

#[starknet::interface]
pub trait ILendingPool<TContractState> {
    fn deposit(
        ref self: TContractState, asset: ContractAddress, user: ContractAddress, amount: u256,
    );
    fn withdraw(
        ref self: TContractState, asset: ContractAddress, user: ContractAddress, amount: u256,
    );
    fn borrow(
        ref self: TContractState, asset: ContractAddress, user: ContractAddress, amount: u256,
    );
    fn repay(ref self: TContractState, asset: ContractAddress, user: ContractAddress, amount: u256);
    fn claim_reward(ref self: TContractState, user: ContractAddress);
    fn add_asset(ref self: TContractState, token: ContractAddress, config: AssetConfig);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn add_yangs_to_pragma(
        ref self: TContractState, pragma_address: ContractAddress, yangs: Array<ContractAddress>,
    );
    fn get_user_info(
        self: @TContractState, user: ContractAddress, asset: ContractAddress,
    ) -> UserInfo;
    fn get_user_infos(
        self: @TContractState, user: ContractAddress, assets: Array<ContractAddress>,
    ) -> Array<UserInfo>;
    fn get_asset_info(
        self: @TContractState, asset: ContractAddress, user: ContractAddress,
    ) -> AssetInfo;
    fn get_asset_infos(
        self: @TContractState, assets: Array<ContractAddress>, user: ContractAddress,
    ) -> Array<AssetInfo>;
    fn get_collateral_value(self: @TContractState, user: ContractAddress) -> u256;
    fn get_user_borrow_limit(
        self: @TContractState, user: ContractAddress, asset: ContractAddress,
    ) -> u256;
    fn get_user_borrow_limit_in_usd(self: @TContractState, user: ContractAddress) -> u256;
    fn get_user_total_value_in_usd(self: @TContractState, user: ContractAddress) -> (u256, u256);
    fn get_max_withdraw_amount(
        self: @TContractState, user: ContractAddress, asset: ContractAddress,
    ) -> u256;
    fn get_user_repay_amount_by_asset(
        self: @TContractState, user: ContractAddress, asset: ContractAddress,
    ) -> u256;
    fn get_pending_rewards(
        self: @TContractState, user: ContractAddress, asset: ContractAddress,
    ) -> u256;
    fn get_asset_price(self: @TContractState, asset_id: ContractAddress) -> u128;
}

#[starknet::contract]
mod LendingPool {
    // OZ
    use openzeppelin_token::erc20::interface::{IERC20SafeDispatcher, IERC20SafeDispatcherTrait};
    use openzeppelin_access::ownable::{OwnableComponent};
    use OwnableComponent::{InternalTrait as OwnableInternalTrait};
    use openzeppelin_security::pausable::{PausableComponent};
    use openzeppelin_security::reentrancyguard::ReentrancyGuardComponent;
    use ReentrancyGuardComponent::{InternalTrait as ReentrancyGuardInternalTrait};

    use super::*;
    use super::super::dsc_token::IDSCDispatcherTrait;
    use super::super::asset_manager::IAssetManagerDispatcherTrait;
    use openzeppelin_token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use contracts::mocks::mock_pragma::{IMockPragmaDispatcher, IMockPragmaDispatcherTrait};
    use pragma_lib::types::{PragmaPricesResponse};
    use starknet::storage::{Vec, VecTrait, MutableVecTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::num::traits::{Zero};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent,
    );

    const PRECISION: u256 = 1000000000000000000; // 1e18
    const PRAGMA_DECIMALS_PRECISION: u256 = 100000000; // 1e8
    const ETH_USD_PAIR_ID: felt252 = 'ETH/USD';
    const STRK_USD_PAIR_ID: felt252 = 'STRK/USD';
    const ETH_INIT_PRICE: u128 = 200000000000; // 2000 * 1e18
    const STRK_INIT_PRICE: u128 = 100000000; // 1 * 1e18
    const PRAGMA_DECIMALS: u8 = 8;
    const DEFAULT_NUM_SOURCES: u32 = 5;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl ReentrancyGuardImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        owner: ContractAddress,
        asset_manager: IAssetManagerDispatcher,
        dsc_token: IDSCDispatcher,
        oracle_address: ContractAddress,
        price_feeds: Map<ContractAddress, felt252>, // token => chainlink feed
        user_infos: Map<ContractAddress, Map<ContractAddress, UserInfo>>,
        asset_infos: Map<ContractAddress, AssetInfo>,
        acc_reward_per_share: Map<ContractAddress, u256>,
        reward_per_block: u128,
        last_reward_block: u64,
        asset_tokens: Vec<ContractAddress>,
        paused: bool,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
        Borrow: Borrow,
        Repay: Repay,
        AssetInfoUpdated: AssetInfoUpdated,
        RewardClaimed: RewardClaimed,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct Deposit {
        #[key]
        asset: ContractAddress,
        #[key]
        user: ContractAddress,
        amount: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        #[key]
        asset: ContractAddress,
        #[key]
        user: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Borrow {
        #[key]
        asset: ContractAddress,
        #[key]
        user: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Repay {
        #[key]
        asset: ContractAddress,
        #[key]
        user: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct AssetInfoUpdated {
        #[key]
        asset: ContractAddress,
        new_rate: u256,
        acc_reward_per_share: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct RewardClaimed {
        #[key]
        asset: ContractAddress,
        #[key]
        user: ContractAddress,
        amount: u256,
    }

    pub mod Errors {
        pub const INVALID_USER: felt252 = 'LP: invalid user';
        pub const INVALID_PRICE_FEED_COUNT: felt252 = 'LP: invalid price feed count';
        pub const INVALID_AMOUNT: felt252 = 'LP: invalid amount';
        pub const INSUFFICIENT_COLLATERAL: felt252 = 'LP: insufficient collateral';
        pub const NOT_LIQUIDATABLE: felt252 = 'LP: not liquidatable';
        pub const WITHDRAWAL_EXCEEDS: felt252 = 'LP: withdrawal exceeds';
        pub const EXCEEDS_BORROW_FACTOR: felt252 = 'LP: exceeds borrow factor';
        pub const INVALID_COLLATERAL_FACTOR: felt252 = 'LP: invalid factor';
        pub const EXCEEDS_LIQUIDITY: felt252 = 'LP: exceeds liquidity';
        pub const APPROVE_FAILED: felt252 = 'LP: approve failed';
        pub const TRANSFER_FAILED: felt252 = 'LP: transfer failed';
        pub const HEALTH_FACTOR_OK: felt252 = 'LP: health factor ok';
        pub const HEALTH_NOT_IMPROVED: felt252 = 'LP: health not improved';
        pub const INSUFFICIENT_BALANCE: felt252 = 'LP: insufficient balance';
        pub const MINT_FAILED: felt252 = 'LP: mint failed';
        pub const INVALID_ORACLE: felt252 = 'PGM: invalid oracle';
        pub const INVALID_PRAGMA: felt252 = 'PGM: invalid pragma';
        pub const INVALID_MOCK_PRAGMA: felt252 = 'PGM: invalid mock pragma';
        pub const INVALID_SYMBOL: felt252 = 'PGM: invalid symbol';
        pub const INVALID_REWARD_DEBT: felt252 = 'LP: invalid reward debt';
        pub const INVALID_BORROW_INTEREST: felt252 = 'LP: invalid borrow interest';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        dsc_token: ContractAddress,
        reward_per_block: u128,
        asset_manager: ContractAddress,
        // token_addresses: Array<ContractAddress>,
        // pair_ids: Array<felt252>,
        oracle_address: ContractAddress,
    ) {
        self.owner.write(owner);
        self.ownable.initializer(owner);
        self.dsc_token.write(IDSCDispatcher { contract_address: dsc_token });
        self.oracle_address.write(oracle_address);
        self.reward_per_block.write(reward_per_block.into());
        self.last_reward_block.write(0);
        self.asset_manager.write(IAssetManagerDispatcher { contract_address: asset_manager });
    }

    #[abi(embed_v0)]
    impl LendingPoolImpl of ILendingPool<ContractState> {
        /// @notice 存款
        /// @param asset 资产地址
        /// @param amount 存款金额
        fn deposit(
            ref self: ContractState, asset: ContractAddress, user: ContractAddress, amount: u256,
        ) {
            self.reentrancy_guard.start();
            self.pausable.assert_not_paused();
            assert(amount > 0, Errors::INVALID_AMOUNT);

            // 更新资产信息和奖励
            InternalFunctions::update_asset_info(ref self, asset);

            let caller = user;
            assert(!caller.is_zero(), Errors::INVALID_USER);
            let mut user_info = self.user_infos.entry(asset).entry(caller).read();
            let asset_info = self.asset_infos.entry(asset).read();

            // 计算累积利息
            let mut accrued_interest = 0;
            if user_info.deposit_amount > 0 {
                accrued_interest =
                    InternalFunctions::calculate_accrued_interest(
                        user_info.deposit_amount.into(),
                        user_info.deposit_index,
                        asset_info.deposit_index,
                    );
            }

            // 更新用户存款信息
            let new_deposit_amount = user_info.deposit_amount.into() + amount + accrued_interest;
            user_info.deposit_amount = new_deposit_amount.try_into().unwrap();
            user_info.deposit_index = asset_info.deposit_index;
            user_info.last_update_time = get_block_timestamp();

            // 计算时间加权金额
            let weighted_amount = if user_info.deposit_amount > 0
                && user_info.last_update_time > 0 {
                calculate_weighted_amount(
                    user_info.deposit_amount, user_info.last_update_time, get_block_timestamp(),
                )
            } else {
                amount
            };

            // 执行转账
            let token = IERC20SafeDispatcher { contract_address: asset };
            let success = token.transfer_from(caller, get_contract_address(), amount);
            assert(success.unwrap(), Errors::TRANSFER_FAILED);

            // TODO: 更新奖励债务
            let acc_reward = self.acc_reward_per_share.entry(asset).read();
            if acc_reward > 0 {
                // let curr_reward = weighted_amount / PRECISION;
                let curr_reward = (weighted_amount * acc_reward) / PRECISION;
                assert(curr_reward >= user_info.reward_debt, Errors::INVALID_REWARD_DEBT);
                let pending = curr_reward - user_info.reward_debt;
                let mint_success = self.dsc_token.read().mint(caller, pending);
                assert(mint_success, Errors::MINT_FAILED);
                user_info.reward_debt = (weighted_amount * acc_reward) / PRECISION;
            }

            // 更新存储
            self.user_infos.entry(asset).entry(caller).write(user_info);
            self
                .asset_infos
                .write(
                    asset,
                    AssetInfo {
                        total_deposits: asset_info.total_deposits + amount + accrued_interest,
                        ..asset_info,
                    },
                );

            // 触发事件
            self.emit(Deposit { asset, user: caller, amount, timestamp: get_block_timestamp() });
            self.reentrancy_guard.end();
        }

        /// @notice 提现
        /// @param asset 资产地址
        /// @param amount 提现金额
        fn withdraw(
            ref self: ContractState, asset: ContractAddress, user: ContractAddress, amount: u256,
        ) {
            self.pausable.assert_not_paused();
            assert(amount > 0, Errors::INVALID_AMOUNT);

            // 更新资产信息和奖励
            InternalFunctions::update_asset_info(ref self, asset);

            let caller = user;
            assert(!caller.is_zero(), Errors::INVALID_USER);
            let mut user_info = self.user_infos.entry(asset).entry(caller).read();
            let mut asset_info = self.asset_infos.entry(asset).read();

            // 计算累积利息
            let deposit_interest = InternalFunctions::calculate_accrued_interest(
                user_info.deposit_amount.into(), user_info.deposit_index, asset_info.deposit_index,
            );

            let total_deposit = user_info.deposit_amount.into() + deposit_interest;
            assert(total_deposit >= amount, Errors::INSUFFICIENT_BALANCE);

            // 检查提现后的抵押率
            let (_, borrowed_value) = self.get_user_total_value_in_usd(caller);
            if borrowed_value > 0 {
                let borrow_limit = self.get_user_borrow_limit_in_usd(caller);
                assert(borrowed_value <= borrow_limit, Errors::WITHDRAWAL_EXCEEDS);
            }

            // 更新用户存款信息
            user_info.deposit_amount = (total_deposit - amount).try_into().unwrap();
            user_info.deposit_index = asset_info.deposit_index;
            user_info.last_update_time = get_block_timestamp();

            // 更新资产信息
            asset_info.total_deposits -= amount;

            // 更新奖励债务
            let acc_reward = self.acc_reward_per_share.entry(asset).read();
            user_info.reward_debt = (user_info.deposit_amount.into() * acc_reward) / PRECISION;

            // 更新存储
            self.user_infos.entry(asset).entry(caller).write(user_info);
            self.asset_infos.write(asset, asset_info);

            // 执行转账
            let token = IERC20SafeDispatcher { contract_address: asset };
            let success = token.transfer(caller, amount.into());
            assert(success.unwrap(), Errors::TRANSFER_FAILED);

            self.emit(Withdraw { asset, user: caller, amount });
        }

        /// @notice 借款
        /// @param asset 资产地址
        /// @param amount 借款金额
        fn borrow(
            ref self: ContractState, asset: ContractAddress, user: ContractAddress, amount: u256,
        ) {
            self.pausable.assert_not_paused();
            assert(amount > 0, Errors::INVALID_AMOUNT);

            // 更新资产信息和奖励
            InternalFunctions::update_asset_info(ref self, asset);

            let caller = user;
            assert(!caller.is_zero(), Errors::INVALID_USER);
            let mut user_info = self.user_infos.entry(asset).entry(caller).read();
            let mut asset_info = self.asset_infos.entry(asset).read();

            // 如果用户已有借款，计算累积利息
            if user_info.borrow_amount > 0 {
                let borrow_interest = InternalFunctions::calculate_accrued_interest(
                    user_info.borrow_amount.into(), user_info.borrow_index, asset_info.borrow_index,
                );
                user_info
                    .borrow_amount = (user_info.borrow_amount.into() + borrow_interest)
                    .try_into()
                    .unwrap();
                asset_info.total_borrows += borrow_interest;
            }

            // 获取价格并计算借款价值
            let price = self.get_asset_price(asset);

            let current_borrow_value = (user_info.borrow_amount * price.into()).into()
                / PRAGMA_DECIMALS_PRECISION;
            let new_borrow_value = (amount * price.into()) / PRAGMA_DECIMALS_PRECISION;
            let borrow_limit = self.get_user_borrow_limit_in_usd(caller);

            // 检查借款限额
            assert(
                current_borrow_value + new_borrow_value <= borrow_limit,
                Errors::EXCEEDS_BORROW_FACTOR,
            );

            // 更新用户借款信息
            user_info.borrow_amount = (user_info.borrow_amount.into() + amount).try_into().unwrap();
            user_info.borrow_index = asset_info.borrow_index;
            user_info.last_update_time = get_block_timestamp();

            // 更新资产总借款
            asset_info.total_borrows += amount;

            // 更新存储
            self.user_infos.entry(asset).entry(caller).write(user_info);
            self.asset_infos.entry(asset).write(asset_info);

            // 执行转账
            let token = IERC20SafeDispatcher { contract_address: asset };
            let success = token.transfer(caller, amount.into());
            assert(success.unwrap(), Errors::TRANSFER_FAILED);

            self.emit(Borrow { asset, user: caller, amount });
        }

        /// @notice 还款
        /// @param asset 资产地址
        /// @param amount 还款金额
        fn repay(
            ref self: ContractState, asset: ContractAddress, user: ContractAddress, amount: u256,
        ) {
            self.pausable.assert_not_paused();
            assert(amount > 0, Errors::INVALID_AMOUNT);

            // 更新资产信息和奖励
            InternalFunctions::update_asset_info(ref self, asset);

            let caller = user;
            assert(!caller.is_zero(), Errors::INVALID_USER);
            let mut user_info = self.user_infos.entry(asset).entry(caller).read();
            let mut asset_info = self.asset_infos.entry(asset).read();

            // 计算累积的借款利息
            let borrow_interest = InternalFunctions::calculate_accrued_interest(
                user_info.borrow_amount.into(), user_info.borrow_index, asset_info.borrow_index,
            );

            // 计算总债务
            let total_debt = user_info.borrow_amount.into() + borrow_interest;
            assert(total_debt > 0, Errors::INVALID_AMOUNT);

            // 计算实际还款金额
            let actual_repay_amount = if amount > total_debt {
                total_debt
            } else {
                amount
            };

            // 更新用户借款信息
            user_info.borrow_amount = (total_debt - actual_repay_amount).try_into().unwrap();
            user_info.borrow_index = asset_info.borrow_index;
            user_info.last_update_time = get_block_timestamp();

            // 更新资产总借款
            asset_info.total_borrows = asset_info.total_borrows
                + borrow_interest
                - actual_repay_amount;

            // 更新存储
            self.user_infos.entry(asset).entry(caller).write(user_info);
            self.asset_infos.entry(asset).write(asset_info);

            // 执行转账
            let token = IERC20SafeDispatcher { contract_address: asset };
            let success = token
                .transfer_from(caller, get_contract_address(), actual_repay_amount.into());
            assert(success.unwrap(), Errors::TRANSFER_FAILED);

            self.emit(Repay { asset, user: caller, amount: actual_repay_amount });
        }

        /// @notice 领取奖励
        /// @param asset 资产地址
        fn claim_reward(ref self: ContractState, user: ContractAddress) {
            self.pausable.assert_not_paused();
            let mut i: u64 = 0;

            loop {
                if i >= self.asset_tokens.len() {
                    break;
                }
                let asset = self.asset_tokens.at(i).read();
                InternalFunctions::update_asset_info(ref self, asset);

                let caller = user;
                assert(!caller.is_zero(), Errors::INVALID_USER);
                let mut user_info = self.user_infos.entry(asset).entry(caller).read();
                let asset_info = self.asset_infos.entry(asset).read();

                // 计算累积的存款利息
                let deposit_interest = InternalFunctions::calculate_accrued_interest(
                    user_info.deposit_amount.into(),
                    user_info.deposit_index,
                    asset_info.deposit_index,
                );

                // 计算时间加权金额
                let weighted_amount = calculate_weighted_amount(
                    (user_info.deposit_amount.into() + deposit_interest).try_into().unwrap(),
                    user_info.last_update_time,
                    get_block_timestamp(),
                );

                // 计算待领取奖励
                let acc_reward = self.acc_reward_per_share.entry(asset).read();
                let pending = (weighted_amount * acc_reward) / PRECISION - user_info.reward_debt;

                if pending > 0 {
                    // 更新用户状态
                    user_info.deposit_index = asset_info.deposit_index;
                    user_info.last_update_time = get_block_timestamp();
                    user_info.reward_debt = (weighted_amount * acc_reward) / PRECISION;

                    // 更新储
                    self.user_infos.entry(asset).entry(caller).write(user_info);

                    // 铸造奖励
                    let mint_success = self.dsc_token.read().mint(caller, pending);
                    assert(mint_success, Errors::MINT_FAILED);

                    self.emit(RewardClaimed { asset, user: caller, amount: pending });
                }
                i += 1;
            }
        }

        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.pause();
        }

        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.unpause();
        }

        fn get_user_info(
            self: @ContractState, user: ContractAddress, asset: ContractAddress,
        ) -> UserInfo {
            self.user_infos.entry(asset).entry(user).read()
        }

        fn get_user_infos(
            self: @ContractState, user: ContractAddress, assets: Array<ContractAddress>,
        ) -> Array<UserInfo> {
            let mut infos = array![];
            for i in 0..assets.len() {
                let asset = *assets.at(i);
                let mut user_info = self.get_user_info(user, asset);
                let price = self.get_asset_price(asset);
                user_info.deposit_amount_usd = (user_info.deposit_amount * price.into())
                    / PRAGMA_DECIMALS_PRECISION;
                user_info.borrow_amount_usd = (user_info.borrow_amount * price.into())
                    / PRAGMA_DECIMALS_PRECISION;
                infos.append(user_info);
            };
            infos
        }

        fn get_asset_info(
            self: @ContractState, asset: ContractAddress, user: ContractAddress,
        ) -> AssetInfo {
            let caller = user;
            assert(!caller.is_zero(), Errors::INVALID_USER);
            let mut asset_info = self.asset_infos.entry(asset).read();
            let erc20 = ERC20ABIDispatcher { contract_address: asset };
            let balance = erc20.balance_of(caller);
            asset_info.user_balance = balance;
            asset_info
        }

        /// @notice 获取资产信息
        /// @param assets 资产地址数组
        /// @return 资产信息数组
        fn get_asset_infos(
            self: @ContractState, assets: Array<ContractAddress>, user: ContractAddress,
        ) -> Array<AssetInfo> {
            let caller = user;
            let mut infos = array![];
            for i in 0..assets.len() {
                let token = *assets.at(i);
                // 获取资产的用户余额
                let erc20 = ERC20ABIDispatcher { contract_address: token };
                let balance: u256 = erc20.balance_of(caller);
                let mut asset_info = self.asset_infos.entry(token).read();
                asset_info.user_balance = balance;
                // 获取资产价格
                let price = self.get_asset_price(token);
                asset_info.asset_price = price;
                // 计算总存款美元
                asset_info.total_deposits_usd = (asset_info.total_deposits * price.into())
                    / PRAGMA_DECIMALS_PRECISION;
                // 计算总借款美元
                asset_info.total_borrows_usd = (asset_info.total_borrows * price.into())
                    / PRAGMA_DECIMALS_PRECISION;
                infos.append(asset_info);
            };
            infos
        }

        /// @notice 获取抵押物价值
        /// @param user 用户地址
        fn get_collateral_value(self: @ContractState, user: ContractAddress) -> u256 {
            let mut total_value = 0;
            let mut i: u64 = 0;

            loop {
                if i >= self.asset_tokens.len() {
                    break;
                }
                let asset = self.asset_tokens.at(i).read();
                let user_info = self.user_infos.entry(asset).entry(user).read();

                if user_info.deposit_amount > 0 {
                    let config = self.asset_manager.read().get_asset_config(asset);

                    let price = self.get_asset_price(asset);

                    let asset_value = (user_info.deposit_amount.into() * price.into())
                        / PRAGMA_DECIMALS_PRECISION;
                    total_value += (asset_value * config.collateral_factor) / PRECISION;
                }
                i += 1;
            };

            total_value
        }

        /// @notice 获取用户借款限额的代币数量
        /// @param user 用户地址
        /// @param asset 资产地址
        fn get_user_borrow_limit(
            self: @ContractState, user: ContractAddress, asset: ContractAddress,
        ) -> u256 {
            // 获取最大借款限额
            let mut total_borrow_limit_value = self.get_user_borrow_limit_in_usd(user);

            // 获取前已借款价值
            let (_, borrowed_value) = self.get_user_total_value_in_usd(user);
            if borrowed_value >= total_borrow_limit_value {
                return 0;
            }

            // 转换为资产数量
            let price: u256 = self.get_asset_price(asset).into();

            ((total_borrow_limit_value - borrowed_value) * PRAGMA_DECIMALS_PRECISION) / price
        }

        /// @notice 获取用户借款限额的金额
        /// @param user
        fn get_user_borrow_limit_in_usd(self: @ContractState, user: ContractAddress) -> u256 {
            let mut total_borrow_limit_in_usd: u256 = 0;
            let mut i: u64 = 0;

            loop {
                if i >= self.asset_tokens.len() {
                    break;
                }
                let current_asset = self.asset_tokens.at(i).read();
                let user_info = self.user_infos.entry(current_asset).entry(user).read();

                if user_info.deposit_amount > 0 {
                    let config = self.asset_manager.read().get_asset_config(current_asset);

                    let price = self.get_asset_price(current_asset);

                    let deposit_value = (user_info.deposit_amount * price.into())
                        / PRAGMA_DECIMALS_PRECISION;
                    let collateral_value = (deposit_value * config.collateral_factor) / PRECISION;
                    let borrow_limit_value = (collateral_value * config.borrow_factor) / PRECISION;
                    total_borrow_limit_in_usd += borrow_limit_value;
                }
                i += 1;
            };
            total_borrow_limit_in_usd
        }

        /// @notice 获取用户总价值
        /// @param user 用户地址
        fn get_user_total_value_in_usd(
            self: @ContractState, user: ContractAddress,
        ) -> (u256, u256) {
            let mut total_deposit_value = 0;
            let mut total_borrow_value = 0;
            let mut i: u64 = 0;

            loop {
                if i >= self.asset_tokens.len() {
                    break;
                }
                let asset = self.asset_tokens.at(i).read();
                let user_info = self.user_infos.entry(asset).entry(user).read();

                let price: u256 = self.get_asset_price(asset).into();

                if user_info.deposit_amount > 0 {
                    let deposit_value = (user_info.deposit_amount.into() * price)
                        / PRAGMA_DECIMALS_PRECISION;
                    total_deposit_value += deposit_value;
                }

                if user_info.borrow_amount > 0 {
                    let borrow_value = (user_info.borrow_amount.into() * price)
                        / PRAGMA_DECIMALS_PRECISION;
                    total_borrow_value += borrow_value;
                }

                i += 1;
            };

            (total_deposit_value, total_borrow_value)
        }

        /// @notice 获取用户最大提现金额
        /// @param user 用户地址
        /// @param asset 资产地址
        fn get_max_withdraw_amount(
            self: @ContractState, user: ContractAddress, asset: ContractAddress,
        ) -> u256 {
            let user_info = self.user_infos.entry(asset).entry(user).read();

            // 如果没有存款，直接返回0
            if user_info.deposit_amount == 0 {
                return 0;
            }

            // 计算当前借款价值和借款限额
            let (_, current_borrows) = self.get_user_total_value_in_usd(user);
            let borrow_limit = self.get_user_borrow_limit_in_usd(user);

            if current_borrows >= borrow_limit {
                return 0;
            }

            // 获取价格
            let price: u256 = self.get_asset_price(asset).into();

            let config = self.asset_manager.read().get_asset_config(asset);

            // 转换为资产数量
            let max_withdraw = if current_borrows > 0 {
                // 有借款的情况，通过借款限额-已借款价值，计算可提现金额
                let available_usd = borrow_limit - current_borrows;
                let collateral_amount_usd = (available_usd * PRECISION) / config.collateral_factor;
                let withdraw_amount_usd = (collateral_amount_usd * PRECISION)
                    / config.borrow_factor;
                (withdraw_amount_usd * PRAGMA_DECIMALS_PRECISION) / price
            } else {
                // 没有借款的情况，通过借款限额反推抵押金额再反推存款金额，即可提现金额
                let collateral_amount_usd = (borrow_limit * PRECISION) / config.collateral_factor;
                let withdraw_amount_usd = (collateral_amount_usd * PRECISION)
                    / config.borrow_factor;
                (withdraw_amount_usd * PRAGMA_DECIMALS_PRECISION) / price
            };

            // 不能超过用户实际存款
            if max_withdraw > user_info.deposit_amount.into() {
                user_info.deposit_amount.into()
            } else {
                max_withdraw
            }
        }

        fn get_user_repay_amount_by_asset(
            self: @ContractState, user: ContractAddress, asset: ContractAddress,
        ) -> u256 {
            let mut repay_amount = 0;

            let user_info = self.user_infos.entry(asset).entry(user).read();
            let asset_info = self.asset_infos.entry(asset).read();

            repay_amount = user_info.borrow_amount.into();
            if user_info.borrow_amount > 0 {
                let time_elapsed = get_block_timestamp() - asset_info.last_update_time;
                if time_elapsed > 0 && asset_info.total_borrows > 0 && asset_info.borrow_rate > 0 {
                    // 计算借款利息
                    let borrow_interest = interest_rate_model_utils::calculate_interest(
                        asset_info.total_borrows, asset_info.borrow_rate, time_elapsed.into(),
                    );
                    repay_amount += borrow_interest;
                }
            }

            repay_amount * PRECISION
        }

        /// @notice 获取用户待领取奖励
        /// @param user 用户地址
        /// @param asset 资产地址
        fn get_pending_rewards(
            self: @ContractState, user: ContractAddress, asset: ContractAddress,
        ) -> u256 {
            let user_info = self.user_infos.entry(asset).entry(user).read();
            let asset_info = self.asset_infos.entry(asset).read();

            // 计算累积的存款利息
            let deposit_interest = InternalFunctions::calculate_accrued_interest(
                user_info.deposit_amount.into(), user_info.deposit_index, asset_info.deposit_index,
            );

            // 计算时间加权金额
            let weighted_amount = calculate_weighted_amount(
                (user_info.deposit_amount.into() + deposit_interest).try_into().unwrap(),
                user_info.last_update_time,
                get_block_timestamp(),
            );
            // 计算待领取奖励
            let acc_reward = self.acc_reward_per_share.entry(asset).read();
            (weighted_amount * acc_reward) / PRECISION - user_info.reward_debt
        }

        /// @notice 添加资产
        /// @param token 资产地址
        /// @param pair_id 价格预言机地址
        /// @param config 资产配置
        fn add_asset(ref self: ContractState, token: ContractAddress, config: AssetConfig) {
            self.ownable.assert_only_owner();

            // 添加价格预言机
            self.price_feeds.write(token, config.pair_id);
            self.asset_tokens.append().write(token);

            // 在资产管理器中添加资产
            self.asset_manager.read().add_asset(token, config);

            // 初始化资产信息
            self
                .asset_infos
                .write(
                    token,
                    AssetInfo {
                        total_deposits: 0,
                        total_borrows: 0,
                        last_update_time: get_block_timestamp(),
                        current_rate: interest_rate_model_utils::calculate_interest_rate(0, 0),
                        borrow_rate: 0,
                        deposit_rate: 0,
                        reserve_factor: 100000000000000000, // 10%
                        borrow_index: PRECISION,
                        deposit_index: PRECISION,
                        user_balance: 0,
                        asset_price: 0,
                        total_deposits_usd: 0,
                        total_borrows_usd: 0,
                    },
                );
        }

        /// @notice 获取资产价格
        /// @param asset_id 资产ID
        fn get_asset_price(self: @ContractState, asset_id: ContractAddress) -> u128 {
            let assetManager = self.asset_manager.read();
            let assetConfig = assetManager.get_asset_config(asset_id);
            let pairId = assetConfig.pair_id;
            let oracle = IPragmaCustomDispatcher { contract_address: self.oracle_address.read() };
            let price = oracle.fetch_price(pairId, true).unwrap();
            price
        }

        fn add_yangs_to_pragma(
            ref self: ContractState, pragma_address: ContractAddress, yangs: Array<ContractAddress>,
        ) {
            let eth_yang = *yangs.at(0);
            let strk_yang = *yangs.at(1);

            let pragma = IPragmaCustomDispatcher { contract_address: pragma_address };
            assert(!pragma.get_oracle().is_zero(), Errors::INVALID_ORACLE);
            // add_yang does an assert on the response decimals, so we
            // need to provide a valid mock response for it to pass
            let mock_pragma = IMockPragmaDispatcher { contract_address: pragma.get_oracle() };
            assert(mock_pragma.contract_address != Zero::zero(), Errors::INVALID_MOCK_PRAGMA);
            InternalFunctions::mock_valid_price_update(
                mock_pragma, eth_yang, ETH_USD_PAIR_ID, ETH_INIT_PRICE, get_block_timestamp(),
            );
            InternalFunctions::mock_valid_price_update(
                mock_pragma, strk_yang, STRK_USD_PAIR_ID, STRK_INIT_PRICE, get_block_timestamp(),
            );
            // Add yangs to Pragma
        // pragma.set_yang_pair_id(eth_yang, ETH_USD_PAIR_ID);
        // pragma.set_yang_pair_id(strk_yang, STRK_USD_PAIR_ID);
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn calculate_accrued_interest(
            principal: u256, user_index: u256, current_index: u256,
        ) -> u256 {
            if user_index == 0 || current_index == 0 || user_index == current_index {
                return 0;
            }
            if current_index - user_index > 0 {
                return 0;
            }
            (principal * (current_index - user_index) / user_index)
        }

        fn update_asset_info(ref self: ContractState, asset: ContractAddress) {
            let mut asset_info = self.asset_infos.entry(asset).read();
            let last_reward_block = self.last_reward_block.read();
            // 更新区块奖励
            if get_block_number() > last_reward_block {
                let reward = if asset_info.total_deposits > 0 {
                    // 区块份数
                    let multiplier: u256 = (get_block_number() - last_reward_block).into();
                    // 区块奖励
                    let reward = multiplier * self.reward_per_block.read().into();
                    // 存款奖励
                    (reward * PRECISION) / asset_info.total_deposits
                } else {
                    0
                };

                // 当前区块奖励
                let current_acc_reward = self.acc_reward_per_share.entry(asset).read();
                // 更新区块奖励
                self.acc_reward_per_share.write(asset, current_acc_reward + reward);
            }

            // 更新利息
            let time_elapsed = if get_block_timestamp() > asset_info.last_update_time {
                get_block_timestamp() - asset_info.last_update_time
            } else {
                0
            };
            if time_elapsed > 0 && asset_info.total_borrows > 0 && asset_info.borrow_rate > 0 {
                // 计算借款利息
                let borrow_interest = interest_rate_model_utils::calculate_interest(
                    asset_info.total_borrows, asset_info.borrow_rate, time_elapsed.into(),
                );
                if borrow_interest > 0 {
                    // 更新借款指数
                    let borrow_index_delta = (borrow_interest * PRECISION)
                        / asset_info.total_borrows;
                    asset_info.borrow_index += borrow_index_delta;
                    asset_info.total_borrows += borrow_interest;

                    // 计算储备金
                    let reserve_amount = (borrow_interest * asset_info.reserve_factor) / PRECISION;
                    if reserve_amount > 0 {
                        self.asset_manager.read().add_reserves(asset, reserve_amount);
                    }

                    // 更新存款利息和指数
                    assert(borrow_interest > reserve_amount, Errors::INVALID_BORROW_INTEREST);
                    let deposit_interest = borrow_interest - reserve_amount;
                    if asset_info.total_deposits > 0 {
                        let deposit_index_delta = (deposit_interest * PRECISION)
                            / asset_info.total_deposits;
                        asset_info.deposit_index += deposit_index_delta;
                        asset_info.total_deposits += deposit_interest;
                    }
                }
            }

            // 更新利率
            if asset_info.total_deposits > 0 && asset_info.total_borrows > 0 {
                asset_info
                    .borrow_rate =
                        interest_rate_model_utils::calculate_interest_rate(
                            asset_info.total_borrows, asset_info.total_deposits,
                        );
                asset_info
                    .deposit_rate =
                        interest_rate_model_utils::calculate_deposit_rate(
                            asset_info.total_borrows,
                            asset_info.total_deposits,
                            asset_info.reserve_factor,
                        );
            }

            asset_info.last_update_time = get_block_timestamp();
            self.last_reward_block.write(get_block_timestamp());
            self.asset_infos.write(asset, asset_info);

            self
                .emit(
                    AssetInfoUpdated {
                        asset,
                        new_rate: asset_info.current_rate,
                        acc_reward_per_share: self.acc_reward_per_share.entry(asset).read(),
                    },
                );
        }

        // Helper function to add a valid price update to the mock Pragma oracle
        // using default values for decimals and number of sources.
        fn mock_valid_price_update(
            mock_pragma: IMockPragmaDispatcher,
            yang: ContractAddress,
            pair_id: felt252,
            price: u128,
            timestamp: u64,
        ) {
            let response = PragmaPricesResponse {
                price: price,
                decimals: PRAGMA_DECIMALS.into(),
                last_updated_timestamp: timestamp,
                num_sources_aggregated: DEFAULT_NUM_SOURCES,
                expiration_timestamp: Option::None,
            };
            mock_pragma.next_get_data_median(pair_id, response);
        }
    }
}

