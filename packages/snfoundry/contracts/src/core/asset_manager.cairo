use starknet::{ContractAddress};

#[derive(Drop, Serde, PartialEq, Debug, starknet::Store)]
pub struct AssetConfig {
    pub is_supported: bool, // 是否支持该资产
    pub symbol: ByteArray, // 代币符号
    pub name: ByteArray, // 代币名称
    pub pair_id: felt252, // 配对 ID
    pub decimals: u8, // 代币小数位
    pub collateral_factor: u256, // 抵押率
    pub borrow_factor: u256, // 借款率
    pub icon: ByteArray // 代币图标 URL
}

#[starknet::interface]
pub trait IAssetManager<TContractState> {
    fn set_lending_pool(ref self: TContractState, lending_pool: ContractAddress);
    fn add_asset(ref self: TContractState, asset: ContractAddress, config: AssetConfig);
    fn update_asset(ref self: TContractState, asset: ContractAddress, config: AssetConfig);
    fn add_reserves(ref self: TContractState, asset: ContractAddress, amount: u256);
    fn update_add_role(ref self: TContractState, granter: ContractAddress, status: bool);
    fn get_asset_config(self: @TContractState, asset: ContractAddress) -> AssetConfig;
    fn get_asset_configs(
        self: @TContractState, assets: Array<ContractAddress>,
    ) -> Array<AssetConfig>;
    fn get_supported_assets(self: @TContractState) -> Array<ContractAddress>;
    fn is_asset_supported(self: @TContractState, asset: ContractAddress) -> bool;
    fn get_asset_reserves(self: @TContractState, asset: ContractAddress) -> u256;
}

#[starknet::contract]
pub mod AssetManager {
    use core::num::traits::{Zero};
    use super::{ContractAddress, IAssetManager, AssetConfig};
    use starknet::{get_caller_address};
    use starknet::storage::{Map, StorageMapWriteAccess, StoragePathEntry};
    use starknet::storage::{Vec, VecTrait, MutableVecTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use openzeppelin_access::ownable::{OwnableComponent};
    use OwnableComponent::{InternalTrait as OwnableInternalTrait};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {
        owner: ContractAddress, // 合约所有者
        lending_pool: ContractAddress, // 借贷池地址
        granters: Map<ContractAddress, bool>, // 创建权限映射
        asset_configs: Map<ContractAddress, AssetConfig>, // 资产配置映射
        supported_assets: Vec<ContractAddress>, // 支持的资产列表
        asset_reserves: Map<ContractAddress, u256>, // 资产储备金映射
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AssetAdded: AssetAdded,
        AssetUpdated: AssetUpdated,
        ReservesAdded: ReservesAdded,
        AdderStatusChanged: AdderStatusChanged,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct AssetAdded {
        #[key]
        asset: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AssetUpdated {
        #[key]
        asset: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ReservesAdded {
        #[key]
        asset: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct AdderStatusChanged {
        #[key]
        granter: ContractAddress,
        status: bool,
    }

    pub mod Errors {
        pub const ZERO_ADDRESS: felt252 = 'AM: zero address';
        pub const INVALID_CALLER: felt252 = 'AM: invalid caller';
        pub const NOT_SUPPORTED: felt252 = 'AM: not supported';
        pub const INVALID_AMOUNT: felt252 = 'AM: invalid amount';
        pub const INVALID_FACTOR: felt252 = 'AM: invalid factor';
        pub const ALREADY_SUPPORTED: felt252 = 'AM: already supported';
        pub const NOT_OWNER: felt252 = 'AM: not owner';
        pub const NOT_LENDING_POOL: felt252 = 'AM: not lending pool';
    }

    const MAX_FACTOR: u256 = 1_000_000_000_000_000_000;

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl AssetManagerImpl of IAssetManager<ContractState> {
        fn set_lending_pool(ref self: ContractState, lending_pool: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(!lending_pool.is_zero(), Errors::ZERO_ADDRESS);
            self.lending_pool.write(lending_pool);
        }

        /// @notice 添加新资产
        /// @param asset 资产地址
        /// @param config 资产配置
        /// @dev 只能被合约所有者或具有创建权限的地址调用
        fn add_asset(ref self: ContractState, asset: ContractAddress, config: AssetConfig) {
            self.assert_only_owner_or_granter();
            assert(!asset.is_zero(), Errors::ZERO_ADDRESS);
            assert(!self.asset_configs.entry(asset).is_supported.read(), Errors::ALREADY_SUPPORTED);
            assert(config.collateral_factor <= MAX_FACTOR, Errors::INVALID_FACTOR);
            assert(config.borrow_factor <= MAX_FACTOR, Errors::INVALID_FACTOR);

            self.asset_configs.write(asset, config);
            self.supported_assets.append().write(asset);
            self.emit(AssetAdded { asset });
        }

        /// @notice 更新资产配置
        /// @param asset 资产地址
        /// @param config 新的资产配置
        /// @dev 只能被合约所有者或具有创建权限的地址调用
        fn update_asset(ref self: ContractState, asset: ContractAddress, config: AssetConfig) {
            self.assert_only_owner_or_granter();
            assert(self.asset_configs.entry(asset).is_supported.read(), Errors::NOT_SUPPORTED);
            assert(config.collateral_factor <= MAX_FACTOR, Errors::INVALID_FACTOR);
            assert(config.borrow_factor <= MAX_FACTOR, Errors::INVALID_FACTOR);

            self.asset_configs.write(asset, config);
            self.emit(AssetUpdated { asset });
        }

        /// @notice 添加储备金
        /// @param asset 资产地址
        /// @param amount 储备金金额
        /// @dev 只能被 LendingPool 调用
        fn add_reserves(ref self: ContractState, asset: ContractAddress, amount: u256) {
            self.assert_only_lending_pool();
            assert(self.is_asset_supported(asset), Errors::NOT_SUPPORTED);

            let current_reserves = self.asset_reserves.entry(asset).read();
            self.asset_reserves.write(asset, current_reserves + amount);
            self.emit(ReservesAdded { asset, amount });
        }

        /// @notice 更新创建权限
        /// @param granter 创建者地址
        /// @param status 权限状态
        fn update_add_role(ref self: ContractState, granter: ContractAddress, status: bool) {
            self.ownable.assert_only_owner();

            self.granters.write(granter, status);
            self.emit(AdderStatusChanged { granter, status });
        }

        /// @notice 获取资产配置
        /// @param asset 资产地址
        /// @return 资产配置
        fn get_asset_config(self: @ContractState, asset: ContractAddress) -> AssetConfig {
            self.asset_configs.entry(asset).read()
        }

        fn get_asset_configs(
            self: @ContractState, assets: Array<ContractAddress>,
        ) -> Array<AssetConfig> {
            let mut configs = array![];
            for i in 0..assets.len() {
                configs.append(self.asset_configs.entry(*assets.at(i)).read());
            };
            configs
        }

        /// @notice 获取支持的资产列表
        /// @return 资产地址数组
        fn get_supported_assets(self: @ContractState) -> Array<ContractAddress> {
            let mut addresses = array![];
            for i in 0..self.supported_assets.len() {
                addresses.append(self.supported_assets.at(i).read());
            };
            addresses
        }

        /// @notice 检查资产是否支持
        /// @param asset 资产地址
        /// @return 是否支持
        fn is_asset_supported(self: @ContractState, asset: ContractAddress) -> bool {
            self.asset_configs.entry(asset).is_supported.read()
        }

        /// @notice 获取资产储备金
        /// @param asset 资产地址
        /// @return 储备金金额
        fn get_asset_reserves(self: @ContractState, asset: ContractAddress) -> u256 {
            self.asset_reserves.entry(asset).read()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        /// @notice 检查调用者是否为合约所有者或具有创建权限的地址
        fn assert_only_owner_or_granter(self: @ContractState) {
            let caller = get_caller_address();
            assert(
                caller == self.owner.read() || self.granters.entry(caller).read(),
                Errors::INVALID_CALLER,
            );
        }

        fn assert_only_lending_pool(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self.lending_pool.read(), Errors::NOT_LENDING_POOL);
        }
    }
}

