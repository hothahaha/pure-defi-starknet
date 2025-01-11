use starknet::ContractAddress;

#[starknet::interface]
pub trait IPragmaCustom<TContractState> {
    fn set_yang_pair_id(ref self: TContractState, yang: ContractAddress, pair_id: felt252);
    fn set_price_validity_thresholds(ref self: TContractState, freshness: u64, sources: u32);
    fn get_name(self: @TContractState) -> felt252;
    fn get_oracle(self: @TContractState) -> ContractAddress;
    fn fetch_price(
        ref self: TContractState, pair_id: felt252, force_update: bool,
    ) -> Result<u128, felt252>;
}

#[starknet::contract]
pub mod PragmaCustom {
    use contracts::interfaces::external::{IPragmaOracleDispatcher, IPragmaOracleDispatcherTrait};
    use pragma_lib::types::{DataType, PragmaPricesResponse};
    use starknet::storage::{Map, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::num::traits::{Zero};
    use starknet::{get_block_timestamp};
    use super::*;

    //
    // Constants
    //

    const LOWER_FRESHNESS_BOUND: u64 = 60; // 1 minute
    const UPPER_FRESHNESS_BOUND: u64 = 4 * 60 * 60; // 4 hours * 60 minutes * 60 seconds
    const LOWER_SOURCES_BOUND: u32 = 3;
    const UPPER_SOURCES_BOUND: u32 = 13;

    //
    // Storage
    //

    #[storage]
    struct Storage {
        oracle: IPragmaOracleDispatcher,
        price_validity_thresholds: PriceValidityThresholds,
        yang_pair_ids: Map::<ContractAddress, felt252>,
    }

    //
    // Events
    //

    #[event]
    #[derive(Copy, Drop, starknet::Event, PartialEq)]
    enum Event {
        YangPairIdSet: YangPairIdSet,
        PriceValidityThresholdsUpdated: PriceValidityThresholdsUpdated,
    }

    #[derive(Copy, Drop, starknet::Event, PartialEq)]
    struct PriceValidityThresholdsUpdated {
        old_thresholds: PriceValidityThresholds,
        new_thresholds: PriceValidityThresholds,
    }

    #[derive(Copy, Drop, starknet::Event, PartialEq)]
    struct YangPairIdSet {
        address: ContractAddress,
        pair_id: felt252,
    }

    #[derive(Copy, Drop, PartialEq, Serde, starknet::Store)]
    struct PriceValidityThresholds {
        // 价格有效性阈值
        freshness: u64,
        // 价格来源数量阈值
        sources: u32,
    }

    //
    // Constructor
    //

    #[constructor]
    fn constructor(
        ref self: ContractState,
        oracle: ContractAddress,
        freshness_threshold: u64,
        sources_threshold: u32,
    ) {
        // init storage
        self.oracle.write(IPragmaOracleDispatcher { contract_address: oracle });
        let new_thresholds = PriceValidityThresholds {
            freshness: freshness_threshold, sources: sources_threshold,
        };
        self.price_validity_thresholds.write(new_thresholds);

        self
            .emit(
                PriceValidityThresholdsUpdated {
                    old_thresholds: PriceValidityThresholds { freshness: 0, sources: 0 },
                    new_thresholds,
                },
            );
    }

    //
    // External Pragma functions
    //

    #[abi(embed_v0)]
    impl PragmaCustomImpl of IPragmaCustom<ContractState> {
        fn set_yang_pair_id(ref self: ContractState, yang: ContractAddress, pair_id: felt252) {
            assert(pair_id != 0, 'PGM: Invalid pair ID');
            assert(yang.is_non_zero(), 'PGM: Invalid yang address');

            // doing a sanity check if Pragma actually offers a price feed
            // of the requested asset and if it's suitable for our needs
            let response: PragmaPricesResponse = self
                .oracle
                .read()
                .get_data_median(DataType::SpotEntry(pair_id));
            // Pragma returns 0 decimals for an unknown pair ID
            assert(response.decimals.is_non_zero(), 'PGM: Unknown pair ID');
            assert(response.decimals <= 18, 'PGM: Too many decimals');

            self.yang_pair_ids.write(yang, pair_id);

            self.emit(YangPairIdSet { address: yang, pair_id });
        }

        fn set_price_validity_thresholds(ref self: ContractState, freshness: u64, sources: u32) {
            assert(
                LOWER_FRESHNESS_BOUND <= freshness && freshness <= UPPER_FRESHNESS_BOUND,
                'PGM: Freshness out of bounds',
            );
            assert(
                LOWER_SOURCES_BOUND <= sources && sources <= UPPER_SOURCES_BOUND,
                'PGM: Sources out of bounds',
            );

            let old_thresholds: PriceValidityThresholds = self.price_validity_thresholds.read();
            let new_thresholds = PriceValidityThresholds { freshness, sources };
            self.price_validity_thresholds.write(new_thresholds);

            self.emit(PriceValidityThresholdsUpdated { old_thresholds, new_thresholds });
        }

        fn get_name(self: @ContractState) -> felt252 {
            'Pragma'
        }

        fn get_oracle(self: @ContractState) -> ContractAddress {
            self.oracle.read().contract_address
        }

        fn fetch_price(
            ref self: ContractState, pair_id: felt252, force_update: bool,
        ) -> Result<u128, felt252> {
            assert(pair_id.is_non_zero(), 'PGM: Unknown yang');

            let response: PragmaPricesResponse = self
                .oracle
                .read()
                .get_data_median(DataType::SpotEntry(pair_id));

            let price: u128 = response.price;

            // if we receive what we consider a valid price from the oracle,
            // return it back, otherwise emit an event about the update being invalid
            // the check can be overridden with the `force_update` flag
            if force_update || self.is_valid_price_update(response) {
                return Result::Ok(price);
            }

            Result::Err('PGM: Invalid price update')
        }
    }

    //
    // Internal functions
    //

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn is_valid_price_update(self: @ContractState, update: PragmaPricesResponse) -> bool {
            let required: PriceValidityThresholds = self.price_validity_thresholds.read();

            // check if the update is from enough sources
            let has_enough_sources = required.sources <= update.num_sources_aggregated;

            // it is possible that the last_updated_ts is greater than the block_timestamp (in other
            // words, it is from the future from the chain's perspective), because the update
            // timestamp is coming from a data publisher while the block timestamp from the
            // sequencer, they can be out of sync
            //
            // in such a case, we base the whole validity check only on the number of sources and we
            // trust Pragma with regards to data freshness - they have a check in place where they
            // discard updates that are too far in the future
            //
            // we considered having our own "too far in the future" check but that could lead to us
            // discarding updates in cases where just a single publisher would push updates with
            // future timestamp; that could be disastrous as we would have stale prices
            let block_timestamp = get_block_timestamp();
            let last_updated_timestamp: u64 = update.last_updated_timestamp;

            if block_timestamp <= last_updated_timestamp {
                return has_enough_sources;
            }

            // the result of `block_timestamp - last_updated_timestamp` can
            // never be negative if the code reaches here
            let is_fresh = (block_timestamp - last_updated_timestamp) <= required.freshness;

            has_enough_sources && is_fresh
        }
    }
}
