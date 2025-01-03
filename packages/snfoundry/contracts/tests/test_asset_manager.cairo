use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use core::num::traits::{Zero};
use contracts::core::asset_manager::{
    IAssetManagerDispatcher, IAssetManagerDispatcherTrait, AssetConfig,
};

fn deploy_asset_manager() -> ContractAddress {
    let owner = contract_address_const::<0x123>();
    let contract = declare("AssetManager").unwrap().contract_class();
    let constructor_args = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    contract_address
}

#[test]
fn test_add_asset() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let token = contract_address_const::<0x456>();

    start_cheat_caller_address(contract_address, owner);
    dispatcher
        .add_asset(
            token,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 800000000000000000, // 80%
                borrow_factor: 500000000000000000, // 50%
                icon: "",
            },
        );
    stop_cheat_caller_address(contract_address);

    assert(dispatcher.is_asset_supported(token), 'asset should be supported');
}

#[test]
#[should_panic(expected: ('AM: invalid caller',))]
fn test_add_asset_not_owner() {
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let user = contract_address_const::<0x456>();
    let token = contract_address_const::<0x789>();

    start_cheat_caller_address(contract_address, user);
    dispatcher
        .add_asset(
            token,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 800000000000000000, // 80%
                borrow_factor: 500000000000000000, // 50%
                icon: "",
            },
        );
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_update_asset() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let token = contract_address_const::<0x456>();

    // 先添加资产
    start_cheat_caller_address(contract_address, owner);
    dispatcher
        .add_asset(
            token,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 800000000000000000, // 80%
                borrow_factor: 500000000000000000, // 50%
                icon: "",
            },
        );

    // 更新资产配置
    dispatcher
        .update_asset(
            token,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 700000000000000000, // 修改抵押率
                borrow_factor: 600000000000000000, // 修改借款率
                icon: "",
            },
        );
    stop_cheat_caller_address(contract_address);

    let config = dispatcher.get_asset_config(token);
    assert(config.collateral_factor == 700000000000000000, 'wrong collateral factor');
    assert(config.borrow_factor == 600000000000000000, 'wrong borrow factor');
}

#[test]
fn test_add_reserves() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let token = contract_address_const::<0x456>();
    let lending_pool = contract_address_const::<0x789>();

    // 添加资产
    start_cheat_caller_address(contract_address, owner);
    dispatcher
        .add_asset(
            token,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 800000000000000000,
                borrow_factor: 500000000000000000,
                icon: "",
            },
        );

    // 设置 lending pool
    dispatcher.set_lending_pool(lending_pool);
    stop_cheat_caller_address(contract_address);

    // 添加储备金
    start_cheat_caller_address(contract_address, lending_pool);
    dispatcher.add_reserves(token, 1000);
    stop_cheat_caller_address(contract_address);

    assert(dispatcher.get_asset_reserves(token) == 1000, 'wrong reserves amount');
}

#[test]
#[should_panic(expected: ('AM: not lending pool',))]
fn test_add_reserves_not_lending_pool() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let token = contract_address_const::<0x456>();
    let user = contract_address_const::<0x789>();

    // 添加资产
    start_cheat_caller_address(contract_address, owner);
    dispatcher
        .add_asset(
            token,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 800000000000000000,
                borrow_factor: 500000000000000000,
                icon: "",
            },
        );
    stop_cheat_caller_address(contract_address);

    // 非 lending pool 尝试添加储备金
    start_cheat_caller_address(contract_address, user);
    dispatcher.add_reserves(token, 1000);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_update_add_role() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let granter = contract_address_const::<0x456>();
    let token = contract_address_const::<0x789>();

    // 添加 granter
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_add_role(granter, true);
    stop_cheat_caller_address(contract_address);

    // granter 添加资产
    start_cheat_caller_address(contract_address, granter);
    dispatcher
        .add_asset(
            token,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 800000000000000000,
                borrow_factor: 500000000000000000,
                icon: "",
            },
        );
    stop_cheat_caller_address(contract_address);

    assert(dispatcher.is_asset_supported(token), 'asset should be supported');
}

#[test]
#[should_panic(expected: ('AM: invalid factor',))]
fn test_add_asset_invalid_collateral_factor() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let token = contract_address_const::<0x456>();

    start_cheat_caller_address(contract_address, owner);
    dispatcher
        .add_asset(
            token,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 1100000000000000000, // 110% > 100%
                borrow_factor: 500000000000000000,
                icon: "",
            },
        );
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('AM: zero address',))]
fn test_add_asset_zero_address() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    dispatcher
        .add_asset(
            Zero::zero(),
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 800000000000000000,
                borrow_factor: 500000000000000000,
                icon: "",
            },
        );
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('AM: already supported',))]
fn test_add_asset_already_supported() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let token = contract_address_const::<0x456>();

    start_cheat_caller_address(contract_address, owner);
    // 添加第一次
    dispatcher
        .add_asset(
            token,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 800000000000000000,
                borrow_factor: 500000000000000000,
                icon: "",
            },
        );

    // 尝试再次添加相同资产
    dispatcher
        .add_asset(
            token,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 700000000000000000,
                borrow_factor: 400000000000000000,
                icon: "",
            },
        );
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('AM: not supported',))]
fn test_update_asset_not_supported() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let token = contract_address_const::<0x456>();

    start_cheat_caller_address(contract_address, owner);
    dispatcher
        .update_asset(
            token,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 800000000000000000,
                borrow_factor: 500000000000000000,
                icon: "",
            },
        );
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_get_supported_assets() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let token1 = contract_address_const::<0x456>();
    let token2 = contract_address_const::<0x789>();

    start_cheat_caller_address(contract_address, owner);
    // 添加两个资产
    dispatcher
        .add_asset(
            token1,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 800000000000000000,
                borrow_factor: 500000000000000000,
                icon: "",
            },
        );

    dispatcher
        .add_asset(
            token2,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 700000000000000000,
                borrow_factor: 400000000000000000,
                icon: "",
            },
        );
    stop_cheat_caller_address(contract_address);

    let supported_assets = dispatcher.get_supported_assets();
    assert(supported_assets.len() == 2, 'wrong number of assets');
    assert(*supported_assets.at(0) == token1, 'wrong first asset');
    assert(*supported_assets.at(1) == token2, 'wrong second asset');
}

#[test]
#[should_panic(expected: ('AM: zero address',))]
fn test_set_lending_pool_zero_address() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    dispatcher.set_lending_pool(Zero::zero());
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_lending_pool_not_owner() {
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let user = contract_address_const::<0x456>();
    let lending_pool = contract_address_const::<0x789>();

    start_cheat_caller_address(contract_address, user);
    dispatcher.set_lending_pool(lending_pool);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('AM: not supported',))]
fn test_add_reserves_unsupported_asset() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let token = contract_address_const::<0x456>();
    let lending_pool = contract_address_const::<0x789>();

    // 设置 lending pool
    start_cheat_caller_address(contract_address, owner);
    dispatcher.set_lending_pool(lending_pool);
    stop_cheat_caller_address(contract_address);

    // 尝试为未支持的资产添加储备金
    start_cheat_caller_address(contract_address, lending_pool);
    dispatcher.add_reserves(token, 1000);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_get_asset_config_unsupported_asset() {
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let token = contract_address_const::<0x456>();

    let config = dispatcher.get_asset_config(token);
    assert(!config.is_supported, 'should not be supported');
    assert(config.collateral_factor == 0, 'wrong collateral factor');
    assert(config.borrow_factor == 0, 'wrong borrow factor');
}

#[test]
fn test_get_asset_reserves_unsupported_asset() {
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let token = contract_address_const::<0x456>();

    let reserves = dispatcher.get_asset_reserves(token);
    assert(reserves == 0, 'wrong reserves amount');
}

#[test]
fn test_get_supported_assets_empty() {
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };

    let supported_assets = dispatcher.get_supported_assets();
    assert(supported_assets.len() == 0, 'should be empty');
}

#[test]
#[should_panic(expected: ('AM: invalid factor',))]
fn test_update_asset_invalid_borrow_factor() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_asset_manager();
    let dispatcher = IAssetManagerDispatcher { contract_address };
    let token = contract_address_const::<0x456>();

    // 先添加资产
    start_cheat_caller_address(contract_address, owner);
    dispatcher
        .add_asset(
            token,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 800000000000000000,
                borrow_factor: 500000000000000000,
                icon: "",
            },
        );

    // 尝试更新为无效的借款率
    dispatcher
        .update_asset(
            token,
            AssetConfig {
                is_supported: true,
                symbol: "STRK",
                name: "STRK",
                pair_id: 'STRK/ETH',
                decimals: 18,
                collateral_factor: 800000000000000000,
                borrow_factor: 1100000000000000000, // 110% > 100%
                icon: "",
            },
        );
    stop_cheat_caller_address(contract_address);
}
