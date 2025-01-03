use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use contracts::core::dsc_token::{IDSCDispatcher, IDSCDispatcherTrait};

fn deploy_dsc() -> ContractAddress {
    let owner = contract_address_const::<0x123>();
    let contract = declare("DSCToken").unwrap().contract_class();
    let constructor_args = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    let dispatcher = IDSCDispatcher { contract_address };
    // 添加 minter
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_minter(owner, true);
    stop_cheat_caller_address(contract_address);
    contract_address
}

#[test]
#[should_panic(expected: ('DSC: not minter',))]
fn test_mint_not_minter() {
    let contract_address = deploy_dsc();
    let dispatcher = IDSCDispatcher { contract_address };
    let recipient = contract_address_const::<0x456>();
    let amount: u256 = 1000;

    // 非 minter 不能铸币
    start_cheat_caller_address(contract_address, recipient);
    dispatcher.mint(recipient, amount);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_mint() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_dsc();
    let dispatcher = IDSCDispatcher { contract_address };
    let amount: u256 = 1000;

    // minter 可以铸币
    start_cheat_caller_address(contract_address, owner);
    dispatcher.mint(owner, amount);
    assert_eq!(dispatcher.balance_of(owner), amount.into());
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_burn() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_dsc();
    let dispatcher = IDSCDispatcher { contract_address };
    let user = contract_address_const::<0x456>();
    let amount: u256 = 1000;

    // 先铸币
    start_cheat_caller_address(contract_address, owner);
    dispatcher.mint(user, amount);
    stop_cheat_caller_address(contract_address);

    // 用户可以销毁自己的代币
    start_cheat_caller_address(contract_address, user);
    dispatcher.burn(500);
    assert_eq!(dispatcher.balance_of(user), 500);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_pause_not_owner() {
    let user = contract_address_const::<0x456>();
    let contract_address = deploy_dsc();
    let dispatcher = IDSCDispatcher { contract_address };

    start_cheat_caller_address(contract_address, user);
    dispatcher.pause();
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_pause_unpause() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_dsc();
    let dispatcher = IDSCDispatcher { contract_address };

    // 所有者可以暂停和恢复
    start_cheat_caller_address(contract_address, owner);
    dispatcher.pause();
    dispatcher.unpause();
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_minter_management() {
    let owner = contract_address_const::<0x123>();
    let contract_address = deploy_dsc();
    let dispatcher = IDSCDispatcher { contract_address };
    let minter = contract_address_const::<0x456>();

    // 所有者可以添加和移除 minter
    start_cheat_caller_address(contract_address, owner);
    dispatcher.update_minter(minter, true);
    dispatcher.update_minter(minter, false);
    stop_cheat_caller_address(contract_address);
}
