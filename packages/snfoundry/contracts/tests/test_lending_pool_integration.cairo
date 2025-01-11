use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp,
    stop_cheat_block_timestamp,
};
use contracts::core::lending_pool::{ILendingPoolDispatcher, ILendingPoolDispatcherTrait};
use contracts::core::dsc_token::{IDSCDispatcher, IDSCDispatcherTrait};
use super::test_lending_pool::{deploy_contracts};

fn setup() -> (ContractAddress, ContractAddress, ContractAddress, Array<ContractAddress>) {
    let owner = contract_address_const::<0x123>();
    deploy_contracts(owner) // 复用单元测试中的部署函数
}

#[test]
fn test_full_lending_cycle() {
    let (dsc_address, _, lending_pool_address, token_addresses) = setup();
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };
    let dsc = IDSCDispatcher { contract_address: dsc_address };

    let user1 = contract_address_const::<0x456>();
    let user2 = contract_address_const::<0x789>();
    let token = token_addresses.at(0);

    // 用户1存款
    start_cheat_caller_address(lending_pool_address, user1);
    lending_pool.deposit(*token, user1, 10000000000000000000);
    stop_cheat_caller_address(lending_pool_address);

    // 用户2借款
    start_cheat_caller_address(lending_pool_address, user2);
    lending_pool.deposit(*token, user2, 20000000000000000000);
    lending_pool.borrow(*token, user2, 5000000000000000000);
    stop_cheat_caller_address(lending_pool_address);

    // 等待一段时间
    start_cheat_block_timestamp(lending_pool_address, 3600 * 24 * 30);

    // 用户2还款
    start_cheat_caller_address(lending_pool_address, user2);
    lending_pool.repay(*token, user2, 5000000000000000000);
    stop_cheat_caller_address(lending_pool_address);

    // 用户1领取奖励
    start_cheat_caller_address(lending_pool_address, user1);
    lending_pool.claim_reward(user1);
    stop_cheat_caller_address(lending_pool_address);

    stop_cheat_block_timestamp(lending_pool_address);

    // 验证状态
    assert(dsc.balance_of(user1) > 0, 'User1 should have rewards');
}

#[test]
fn test_multiple_users_interaction() {
    let (dsc_address, _, lending_pool_address, token_addresses) = setup();
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };
    let dsc = IDSCDispatcher { contract_address: dsc_address };

    let user1 = contract_address_const::<0x456>();
    let user2 = contract_address_const::<0x789>();
    let token = token_addresses.at(0);

    // 用户1和用户2存款不同金额
    start_cheat_caller_address(lending_pool_address, user1);
    lending_pool.deposit(*token, user1, 50000000000000000000);
    stop_cheat_caller_address(lending_pool_address);

    start_cheat_caller_address(lending_pool_address, user2);
    lending_pool.deposit(*token, user2, 70000000000000000000);
    stop_cheat_caller_address(lending_pool_address);

    // 等待一段时间
    start_cheat_block_timestamp(lending_pool_address, 3600);

    // 用户1和用户2借款不同金额
    start_cheat_caller_address(lending_pool_address, user1);
    lending_pool.borrow(*token, user1, 20000000000000000000);
    stop_cheat_caller_address(lending_pool_address);

    start_cheat_caller_address(lending_pool_address, user2);
    lending_pool.borrow(*token, user2, 20000000000000000000);
    stop_cheat_caller_address(lending_pool_address);

    // 验证奖励分配
    let rewards1 = lending_pool.get_pending_rewards(user1, *token);
    let rewards2 = lending_pool.get_pending_rewards(user2, *token);
    assert(rewards1 > 0, 'User1 should have rewards');
    assert(rewards2 > 0, 'User2 should have rewards');

    // 用户领取奖励
    start_cheat_caller_address(lending_pool_address, user1);
    lending_pool.claim_reward(user1);
    let balance1 = dsc.balance_of(user1);
    stop_cheat_caller_address(lending_pool_address);

    start_cheat_caller_address(lending_pool_address, user2);
    lending_pool.claim_reward(user2);
    let balance2 = dsc.balance_of(user2);
    stop_cheat_caller_address(lending_pool_address);

    stop_cheat_block_timestamp(lending_pool_address);

    assert(balance2 > balance1, 'User2 should have more DSC');
}

#[test]
fn test_interest_accrual() {
    let (_, _, lending_pool_address, token_addresses) = setup();
    let lending_pool = ILendingPoolDispatcher { contract_address: lending_pool_address };

    let lender = contract_address_const::<0x456>();
    let token = token_addresses.at(0);

    // 存款人存款
    start_cheat_caller_address(lending_pool_address, lender);
    lending_pool.deposit(*token, lender, 10000000000000000000);
    lending_pool.borrow(*token, lender, 5000000000000000000);
    lending_pool.deposit(*token, lender, 2000000000000000000);
    stop_cheat_caller_address(lending_pool_address);

    // 等待一段时间让利息累积
    start_cheat_block_timestamp(lending_pool_address, 3600 * 24 * 30); // 1天

    // 检查利息累积
    let borrower_info = lending_pool.get_user_repay_amount_by_asset(lender, *token);
    assert(borrower_info > 5, 'interest should accrue');
}

