pub mod core {
    pub mod lending_pool;
    pub mod asset_manager;
    pub mod dsc_token;
    pub mod pragma_custom;
    pub mod utils {
        pub mod time_weighted_rewards_utils;
        pub mod interest_rate_model_utils;
    }
}
pub mod interfaces {
    pub mod external;
}
pub mod mocks {
    pub mod mock_erc20_eth;
    pub mod mock_erc20_strk;
    pub mod mock_pragma;
}

#[cfg(test)]
mod test {}
