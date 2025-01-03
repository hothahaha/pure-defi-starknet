use pragma_lib::types::{DataType, PragmaPricesResponse};

#[starknet::interface]
pub trait IPragmaOracle<TContractState> {
    // getters
    fn get_data_median(self: @TContractState, data_type: DataType) -> PragmaPricesResponse;
}

#[starknet::interface]
trait ITask<TContractState> {
    fn probe_task(self: @TContractState) -> bool;
    fn execute_task(ref self: TContractState);
}
