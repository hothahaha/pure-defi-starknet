use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use core::num::traits::{Bounded, Zero};
use contracts::core::lending_pool::{ILendingPoolDispatcher, ILendingPoolDispatcherTrait};
use contracts::core::dsc_token::{IDSCDispatcher, IDSCDispatcherTrait};
use contracts::core::asset_manager::{
    IAssetManagerDispatcher, IAssetManagerDispatcherTrait, AssetConfig,
};
use contracts::mocks::mock_erc20_eth::{IMockERC20ETHDispatcher, IMockERC20ETHDispatcherTrait};
use contracts::mocks::mock_erc20_strk::{IMockERC20STRKDispatcher, IMockERC20STRKDispatcherTrait};
use contracts::core::pragma_custom::{IPragmaCustomDispatcher};
use contracts::mocks::mock_pragma::{IMockPragmaDispatcher};

fn TOKEN_ADDRESSES(owner: ContractAddress) -> Array<ContractAddress> {
    let mut token_addresses = ArrayTrait::<ContractAddress>::new();

    // 部署 ETH 合约
    let mock_erc20_eth_contract = declare("MockERC20ETH").unwrap().contract_class();
    let (mock_erc20_eth_address, _) = mock_erc20_eth_contract.deploy(@array![]).unwrap();
    token_addresses.append(mock_erc20_eth_address);

    // 部署 STRK 合约
    let mock_erc20_strk_contract = declare("MockERC20STRK").unwrap().contract_class();
    let (mock_erc20_strk_address, _) = mock_erc20_strk_contract.deploy(@array![]).unwrap();
    token_addresses.append(mock_erc20_strk_address);

    token_addresses
}


fn AGGREGATOR_CONSUMER_ADDRESSES(token_addresses: Array<ContractAddress>) -> ContractAddress {
    let (pragma, _) = pragma_deploy();
    // let mut array: Array<felt252> = array!['ETH/USD', 'STRK/USD'];
    pragma.contract_address
}

/// @notice
/// 为数组中的用户初始化一定数量的代币，并授权借贷池，接着初始化资产管理
fn init_token(
    token_addresses: Array<ContractAddress>,
    users: Array<ContractAddress>,
    lending_pool_address: ContractAddress,
    asset_manager_address: ContractAddress,
) {
    // 循环用户
    let mut i: u32 = 0;
    loop {
        if i >= users.len() {
            break;
        }
        let owner = users.at(i);
        // 循环代币
        let mut j: u32 = 0;
        loop {
            if j >= token_addresses.len() {
                break;
            }
            let token = token_addresses.at(j);
            start_cheat_caller_address(*token, *owner);
            if j == 0 {
                let mock_erc20_eth_dispatcher = IMockERC20ETHDispatcher {
                    contract_address: *token,
                };
                mock_erc20_eth_dispatcher
                    .mint(*owner, 100000000000000000000); // 为 owner 铸造 100 个 ETH
                mock_erc20_eth_dispatcher.approve_token(lending_pool_address, Bounded::MAX);
            } else {
                let mock_erc20_strk_dispatcher = IMockERC20STRKDispatcher {
                    contract_address: *token,
                };
                mock_erc20_strk_dispatcher
                    .mint(*owner, 2000000000000000000000); // 为 owner 铸造 2000 个 STRK
                mock_erc20_strk_dispatcher.approve_token(lending_pool_address, Bounded::MAX);
            }
            stop_cheat_caller_address(*token);
            j += 1;
        };
        i += 1;
    };

    let owner = users.at(0);
    // 为 AssetManager 添加资产
    let mut i: u32 = 0;
    loop {
        if i >= token_addresses.len() {
            break;
        }
        let token = token_addresses.at(i);
        // 为 LendingPool 添加资产
        let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };
        let symbol: ByteArray = if i == 0 {
            "ETH"
        } else {
            "STRK"
        };
        let name: ByteArray = if i == 0 {
            "ETH"
        } else {
            "STRK"
        };
        let pair_id: felt252 = if i == 0 {
            'ETH/USD'
        } else {
            'STRK/USD'
        };
        let collateral_factor: u256 = if i == 0 {
            750000000000000000 // 75%
        } else {
            800000000000000000 // 80%
        };
        let icon: ByteArray = if i == 0 {
            "https://assets.coingecko.com/coins/images/279/small/ethereum.png"
        } else {
            "https://assets.coingecko.com/coins/images/26433/small/starknet.png"
        };
        start_cheat_caller_address(lending_pool_address, *owner);
        lending_pool
            .add_asset(
                *token,
                AssetConfig {
                    is_supported: true,
                    symbol: symbol,
                    name: name,
                    pair_id: pair_id,
                    decimals: 18,
                    collateral_factor: collateral_factor,
                    borrow_factor: 800000000000000000, // 80e16
                    icon: icon,
                },
            );
        stop_cheat_caller_address(lending_pool_address);
        i += 1;
    };
}

pub fn deploy_contracts(
    owner: ContractAddress,
) -> (ContractAddress, ContractAddress, ContractAddress, Array<ContractAddress>) {
    // 部署 DSC Token
    let dsc_contract = declare("DSCToken").unwrap().contract_class();
    let dsc_constructor_args = array![owner.into()];
    let (dsc_address, _) = dsc_contract.deploy(@dsc_constructor_args).unwrap();

    // 部署 Asset Manager
    let asset_manager_contract = declare("AssetManager").unwrap().contract_class();
    let asset_manager_constructor_args = array![owner.into()];
    let (asset_manager_address, _) = asset_manager_contract
        .deploy(@asset_manager_constructor_args)
        .unwrap();

    // 获取代币地址和价格源
    let token_addresses = TOKEN_ADDRESSES(owner);
    let pragma_address = AGGREGATOR_CONSUMER_ADDRESSES(token_addresses.clone());

    // 部署 LendingPool
    let lending_pool_contract = declare("LendingPool").unwrap().contract_class();
    let reward_per_block = 1_000_000_000_000_000; // 1e15

    let mut lending_pool_constructor_args: Array<felt252> = array![];
    Serde::serialize(@owner, ref lending_pool_constructor_args);
    Serde::serialize(@dsc_address, ref lending_pool_constructor_args);
    Serde::serialize(@reward_per_block, ref lending_pool_constructor_args);
    Serde::serialize(@asset_manager_address, ref lending_pool_constructor_args);
    // Serde::serialize(@token_addresses, ref lending_pool_constructor_args);
    // Serde::serialize(@pair_ids, ref lending_pool_constructor_args);
    Serde::serialize(@pragma_address, ref lending_pool_constructor_args);

    let (lending_pool_address, _) = lending_pool_contract
        .deploy(@lending_pool_constructor_args)
        .unwrap();
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };
    lending_pool.add_yangs_to_pragma(pragma_address, token_addresses.clone());
    // lending_pool.add_yangs_to_pragma(pragma_address, *token_addresses.at(0));

    // 初始化权限
    let dsc = IDSCDispatcher { contract_address: dsc_address };
    start_cheat_caller_address(dsc_address, owner);
    dsc.update_minter(lending_pool_address, true);
    stop_cheat_caller_address(dsc_address);

    let asset_manager = IAssetManagerDispatcher { contract_address: asset_manager_address };
    start_cheat_caller_address(asset_manager_address, owner);
    asset_manager.set_lending_pool(lending_pool_address);
    asset_manager.update_add_role(lending_pool_address, true);
    stop_cheat_caller_address(asset_manager_address);

    let user1 = contract_address_const::<0x456>();
    let user2 = contract_address_const::<0x789>();
    init_token(
        token_addresses.clone(),
        array![owner, user1, user2],
        lending_pool_address,
        asset_manager_address,
    );

    (dsc_address, asset_manager_address, lending_pool_address, token_addresses.clone())
}

//
// Constants
//

const FRESHNESS_THRESHOLD: u64 = 30 * 60; // 30 minutes * 60 seconds
const SOURCES_THRESHOLD: u32 = 3;
const UPDATE_FREQUENCY: u64 = 10 * 60; // 10 minutes * 60 seconds
const ETH_USD_PAIR_ID: felt252 = 'ETH/USD';
const STRK_USD_PAIR_ID: felt252 = 'STRK/USD';

//
// Test setup helpers
//

fn mock_pragma_deploy() -> IMockPragmaDispatcher {
    let mut calldata: Array<felt252> = array![];
    let mock_pragma_class = declare("MockPragma").unwrap().contract_class();
    let (mock_pragma_addr, _) = mock_pragma_class.deploy(@calldata).unwrap();

    IMockPragmaDispatcher { contract_address: mock_pragma_addr }
}

fn pragma_deploy() -> (IPragmaCustomDispatcher, IMockPragmaDispatcher) {
    let mock_pragma: IMockPragmaDispatcher = mock_pragma_deploy();
    let mut calldata: Array<felt252> = array![];
    Serde::serialize(@mock_pragma.contract_address, ref calldata);
    Serde::serialize(@FRESHNESS_THRESHOLD, ref calldata);
    Serde::serialize(@SOURCES_THRESHOLD, ref calldata);

    let pragma_class = declare("PragmaCustom").unwrap().contract_class();
    let (pragma_addr, _) = pragma_class.deploy(@calldata).unwrap();

    let pragma = IPragmaCustomDispatcher { contract_address: pragma_addr };

    (pragma, mock_pragma)
}

#[test]
fn test_initiailize_price_feed() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    // 检查 token 地址
    assert(token_addresses.len() == 2, 'wrong token length');
    assert(Zero::is_non_zero(token_addresses.at(0)), 'wrong token address');

    start_cheat_caller_address(lending_pool_address, owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };
    let asset_infos = lending_pool.get_asset_infos(token_addresses.clone(), owner);
    assert(*asset_infos.at(0).user_balance == 100000000000000000000, 'infos wrong balance');

    let asset_info = lending_pool.get_asset_info(*token_addresses.clone().at(0), owner);
    stop_cheat_caller_address(lending_pool_address);
    assert(asset_info.user_balance == 100000000000000000000, 'info wrong balance');
}

#[test]
fn test_deposit() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };

    let token = token_addresses.at(0);

    // 存款
    let amount: u256 = 1000000000000000000;
    start_cheat_caller_address(lending_pool_address, owner);
    lending_pool.deposit(*token, owner, amount.into());
    stop_cheat_caller_address(lending_pool_address);
    let deposit_amount = lending_pool.get_user_info(owner, *token).deposit_amount;
    assert(deposit_amount == amount.into(), 'wrong deposit amount');
    let asset_deposit_amount = lending_pool.get_asset_info(*token, owner).total_deposits;
    assert(asset_deposit_amount == amount.into(), 'wrong asset deposit amount');
}

#[test]
fn test_borrow() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };

    let user = contract_address_const::<0x456>();
    let token = token_addresses.at(0);

    // 先存款
    let deposit_amount: u256 = 1000000000000000000;
    start_cheat_caller_address(lending_pool_address, user);
    lending_pool.deposit(*token, owner, deposit_amount);

    // 再借款
    let borrow_amount: u256 = 50;
    lending_pool.borrow(*token, owner, borrow_amount);
    stop_cheat_caller_address(lending_pool_address);
}

#[test]
fn test_repay() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };

    let user = contract_address_const::<0x456>();
    let token = token_addresses.at(0);

    start_cheat_caller_address(lending_pool_address, user);
    // 存款
    lending_pool.deposit(*token, owner, 1000000000000000000);
    // 借款
    lending_pool.borrow(*token, owner, 500000000000000000);
    // 还款
    lending_pool.repay(*token, owner, 500000000000000000);
    stop_cheat_caller_address(lending_pool_address);
}

#[test]
fn test_claim_reward() {
    let owner = contract_address_const::<0x123>();
    let (dsc_address, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };
    let dsc = IDSCDispatcher { contract_address: dsc_address };

    let user = contract_address_const::<0x456>();
    let token = token_addresses.at(0);

    // 存款并等待一段时间
    lending_pool.deposit(*token, user, 1000000000000000000);

    // 模拟时间流逝
    start_cheat_block_timestamp(lending_pool_address, 3600);

    // 领取奖励
    lending_pool.claim_reward(*token, user);
    stop_cheat_block_timestamp(lending_pool_address);

    // 证用户获得了奖励
    assert(dsc.balance_of(user) > 0, 'Should have rewards');
}

#[test]
#[should_panic(expected: ('LP: invalid amount',))]
fn test_deposit_zero_amount() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };
    let token = token_addresses.at(0);

    start_cheat_caller_address(lending_pool_address, owner);
    lending_pool.deposit(*token, owner, 0);
    stop_cheat_caller_address(lending_pool_address);
}

#[test]
fn test_withdraw() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };
    let token = token_addresses.at(0);

    // 先存款
    let deposit_amount: u256 = 2000000000000000000;
    start_cheat_caller_address(lending_pool_address, owner);
    lending_pool.deposit(*token, owner, deposit_amount);

    // 再提现
    let withdraw_amount: u256 = 1000000000000000000;
    lending_pool.withdraw(*token, owner, withdraw_amount);
    stop_cheat_caller_address(lending_pool_address);

    let user_info = lending_pool.get_user_info(owner, *token);
    assert(user_info.deposit_amount == 1000000000000000000, 'wrong withdraw amount');
}

#[test]
#[should_panic(expected: ('LP: insufficient balance',))]
fn test_withdraw_too_much() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };
    let token = token_addresses.at(0);

    start_cheat_caller_address(lending_pool_address, owner);
    lending_pool.deposit(*token, owner, 1000000000000000000);
    lending_pool.withdraw(*token, owner, 2000000000000000000);
    stop_cheat_caller_address(lending_pool_address);
}

#[test]
fn test_get_collateral_value() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };
    let token = token_addresses.at(0);

    start_cheat_caller_address(lending_pool_address, owner);
    lending_pool.deposit(*token, owner, 1000000000000000000);
    stop_cheat_caller_address(lending_pool_address);

    let collateral_value = lending_pool.get_collateral_value(owner);
    println!("collateral_value: {}", collateral_value);
    assert(collateral_value == 1_500_000_000_000_000_000_000, 'wrong collateral value');
}

#[test]
fn test_get_max_withdraw_amount() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };
    let token = token_addresses.at(0);

    start_cheat_caller_address(lending_pool_address, owner);
    lending_pool.deposit(*token, owner, 100000000000000000000);
    stop_cheat_caller_address(lending_pool_address);

    let max_withdraw = lending_pool.get_max_withdraw_amount(owner, *token);
    assert(max_withdraw == 100000000000000000000, 'wrong max withdraw amount');
}

#[test]
fn test_get_asset_price() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };
    let token = token_addresses.at(0);

    let price = lending_pool.get_asset_price(*token);
    assert(price == 2000000000000000000000, 'wrong ETH price'); // $2000 with 18 decimals
}

#[test]
fn test_get_asset_prices() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };

    // 测试 ETH 价格
    let eth_token = *token_addresses.at(0);
    let eth_price = lending_pool.get_asset_price(eth_token);
    assert(eth_price == 2000000000000000000000, 'wrong ETH price'); // $2000 with 18 decimals

    // 测试 STRK 价格
    let strk_token = *token_addresses.at(1);
    let STRK_price = lending_pool.get_asset_price(strk_token);
    assert(STRK_price == 1000000000000000000, 'wrong STRK price'); // $1 with 8 decimals
}

#[test]
fn test_get_collateral_value_with_prices() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };

    let eth_token = *token_addresses.at(0);
    let strk_token = *token_addresses.at(1);

    // 存入 1 ETH 和 1000 STRK
    start_cheat_caller_address(lending_pool_address, owner);
    lending_pool.deposit(eth_token, owner, 1000000000000000000); // 1 ETH
    lending_pool.deposit(strk_token, owner, 1000000000000000000000); // 1000 STRK
    stop_cheat_caller_address(lending_pool_address);

    // 验证总抵押价值 (1 ETH * $2000) * 0.75 + (1000 STRK * $1) * 0.8 = $2300)
    let collateral_value = lending_pool.get_collateral_value(owner);
    assert(collateral_value == 2300000000000000000000, 'wrong collateral value');
}

#[test]
fn test_get_user_borrow_limit_in_usd() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };

    let user = contract_address_const::<0x456>();
    let token = token_addresses.at(0);

    start_cheat_caller_address(lending_pool_address, user);
    lending_pool.deposit(*token, user, 20000000000000000000);
    stop_cheat_caller_address(lending_pool_address);

    let borrow_limit = lending_pool.get_user_borrow_limit_in_usd(user);
    assert(borrow_limit == 24000000000000000000000, 'wrong borrow limit usd');
}

#[test]
fn test_get_user_borrow_limit() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };

    let user = contract_address_const::<0x456>();

    let token = token_addresses.at(0);
    lending_pool.deposit(*token, user, 1000000000000000000);

    let borrow_limit = lending_pool.get_user_borrow_limit(user, *token);
    assert(borrow_limit == 600000000000000000, 'wrong borrow limit 1');

    let token = token_addresses.at(1);
    lending_pool.deposit(*token, user, 1000000000000000000000);

    let borrow_limit = lending_pool.get_user_borrow_limit(user, *token);
    assert(borrow_limit == 1840000000000000000000, 'wrong borrow limit 2');

    lending_pool.borrow(*token, user, 1000000000000000000000);

    let borrow_limit = lending_pool.get_user_borrow_limit(user, *token);
    assert(borrow_limit == 840000000000000000000, 'wrong borrow limit 3');
}

#[test]
fn test_get_asset_infos() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };

    let token = token_addresses.at(0);
    let amount: u256 = 1000000000000000000;
    lending_pool.deposit(*token, owner, amount);

    let asset_infos = lending_pool.get_asset_infos(token_addresses.clone(), owner);
    assert(
        *asset_infos.at(0).total_deposits_usd == 2000000000000000000000, 'wrong total_deposits_usd',
    );

    let user1 = contract_address_const::<0x456>();
    let amount: u256 = 2000000000000000000;
    lending_pool.deposit(*token, user1, amount);

    let asset_infos = lending_pool.get_asset_infos(token_addresses.clone(), owner);
    assert(
        *asset_infos.at(0).total_deposits_usd == 6000000000000000000000, 'wrong total_deposits_usd',
    );

    let token = token_addresses.at(1);
    let amount: u256 = 1000000000000000000000;
    lending_pool.deposit(*token, owner, amount);

    let asset_infos = lending_pool.get_asset_infos(token_addresses.clone(), owner);
    assert(
        *asset_infos.at(1).total_deposits_usd == 1000000000000000000000, 'wrong total_deposits_usd',
    );
}

#[test]
fn test_get_user_infos() {
    let owner = contract_address_const::<0x123>();
    let (_, _, lending_pool_address, token_addresses) = deploy_contracts(owner);
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };

    let user = contract_address_const::<0x456>();
    let token = token_addresses.at(0);

    lending_pool.deposit(*token, user, 1000000000000000000);

    let user_infos = lending_pool.get_user_infos(user, token_addresses.clone());
    assert(
        *user_infos.at(0).deposit_amount_usd == 2000000000000000000000, 'wrong deposit amount usd',
    );
}

