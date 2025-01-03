const BASE_WEIGHT: u256 = 1000000000000000000; // 1e18
const MAX_WEIGHT_MULTIPLIER: u256 = 2000000000000000000; // 2e18
const MAX_WEIGHT_PERIOD: u256 = 365 * 24 * 60 * 60;
const ONE_MONTH_SECONDS: u256 = 30 * 24 * 60 * 60;

/// @notice 计算时间加权金额
/// @param deposit_amount 存款金额
/// @param last_update_time 上次更新时间
/// @param current_time 当前时间
/// @return 时间加权金额
pub fn calculate_weighted_amount(
    deposit_amount: u256, last_update_time: u64, current_time: u64,
) -> u256 {
    if current_time <= last_update_time {
        return deposit_amount.into();
    }

    let time_diff: u256 = (current_time - last_update_time).into();
    // 使用指数增长而不是线性增长
    let weighted_amount = BASE_WEIGHT
        + ((MAX_WEIGHT_MULTIPLIER - BASE_WEIGHT) * time_diff) / MAX_WEIGHT_PERIOD;
    // 增加基础时间奖励
    let time_bonus: u256 = (time_diff * BASE_WEIGHT) / ONE_MONTH_SECONDS;
    // 增加时间价值的影响
    return (deposit_amount.into() * (weighted_amount + time_bonus)) / BASE_WEIGHT;
}
