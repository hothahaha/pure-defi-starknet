use contracts::core::utils::interest_rate_model_utils::interest_rate_model_utils;
use contracts::core::utils::time_weighted_rewards_utils::calculate_weighted_amount;

const PRECISION: u256 = 1000000000000000000; // 1e18
const SECONDS_PER_YEAR: u256 = 31536000; // 每年秒数

#[test]
fn test_interest_rate_calculation() {
    let total_borrows = 1000000000000000000; // 1 ETH
    let total_deposits = 2000000000000000000; // 2 ETH
    let rate = interest_rate_model_utils::calculate_interest_rate(total_borrows, total_deposits);
    assert(rate > 0, 'interest rate not positive');
}

#[test]
fn test_deposit_rate_calculation() {
    let total_borrows = 1000000000000000000;
    let total_deposits = 2000000000000000000;
    let reserve_factor = 100000000000000000; // 10%
    let rate = interest_rate_model_utils::calculate_deposit_rate(
        total_borrows, total_deposits, reserve_factor,
    );
    assert(rate > 0, 'deposit rate not positive');
}

#[test]
fn test_interest_calculation() {
    let principal = 1000000000000000000; // 1 ETH
    let rate = 100000000000000000; // 10%
    let time_elapsed = 31536000; // 1 year
    let interest = interest_rate_model_utils::calculate_interest(principal, rate, time_elapsed);
    assert(interest > 0, 'interest not positive');
}

#[test]
fn test_weighted_amount_calculation() {
    let deposit_amount: u256 = 1000000000000000000; // 1 ETH
    let last_update_time: u64 = 1000;
    let current_time: u64 = 2000;
    let weighted_amount = calculate_weighted_amount(deposit_amount, last_update_time, current_time);
    assert(weighted_amount > deposit_amount.into(), 'weighted amount not higher');
}

#[test]
#[should_panic(expected: ('IRM: borrows exceed deposits',))]
fn test_interest_rate_calculation_borrows_exceed_deposits() {
    let total_borrows = 2000000000000000000;
    let total_deposits = 1000000000000000000;
    interest_rate_model_utils::calculate_interest_rate(total_borrows, total_deposits);
}

#[test]
fn test_interest_rate_zero_deposits() {
    let total_borrows = 0;
    let total_deposits = 0;
    let rate = interest_rate_model_utils::calculate_interest_rate(total_borrows, total_deposits);
    assert(rate == 20000000000000000, 'should return base rate'); // 2%
}

#[test]
fn test_weighted_amount_same_timestamp() {
    let deposit_amount: u256 = 1000000000000000000;
    let timestamp: u64 = 1000;
    let weighted_amount = calculate_weighted_amount(deposit_amount, timestamp, timestamp);
    assert(weighted_amount == deposit_amount.into(), 'should return same amount');
}

#[test]
fn test_interest_rate_optimal_utilization() {
    // 测试在最优利用率(80%)时的利率
    let total_deposits = 1000000000000000000; // 1 ETH
    let total_borrows = 800000000000000000; // 0.8 ETH
    let rate = interest_rate_model_utils::calculate_interest_rate(total_borrows, total_deposits);
    assert(rate == 80000000000000000, 'wrong optimal rate'); // 应该是 8%
}

#[test]
fn test_interest_rate_above_optimal() {
    // 测试超过最优利用率时的利率
    let total_deposits = 1000000000000000000; // 1 ETH
    let total_borrows = 900000000000000000; // 0.9 ETH = 90% 利用率
    let rate = interest_rate_model_utils::calculate_interest_rate(total_borrows, total_deposits);
    assert(rate > 80000000000000000, 'rate should be above optimal');
    assert(rate < 1000000000000000000, 'rate should be below max');
}

#[test]
fn test_interest_rate_below_optimal() {
    // 测试低于最优利用率时的利率
    let total_deposits = 1000000000000000000; // 1 ETH
    let total_borrows = 400000000000000000; // 0.4 ETH = 40% 利用率
    let rate = interest_rate_model_utils::calculate_interest_rate(total_borrows, total_deposits);
    assert(rate < 800000000000000000, 'rate should be below optimal');
    assert(rate > 20000000000000000, 'rate should be above base');
}

#[test]
fn test_deposit_rate_zero_borrows() {
    let total_borrows = 0;
    let total_deposits = 1000000000000000000;
    let reserve_factor = 100000000000000000; // 10%
    let rate = interest_rate_model_utils::calculate_deposit_rate(
        total_borrows, total_deposits, reserve_factor,
    );
    assert(rate == 0, 'rate should be zero');
}

#[test]
fn test_deposit_rate_full_utilization() {
    let total_deposits = 100;
    let total_borrows = total_deposits; // 100% 利用率
    let reserve_factor = 100000000000000000; // 10%
    let rate = interest_rate_model_utils::calculate_deposit_rate(
        total_borrows, total_deposits, reserve_factor,
    );
    // 存款利率应该是借款利率 * (1 - 储备金率)
    let borrow_rate = interest_rate_model_utils::calculate_interest_rate(
        total_borrows, total_deposits,
    );
    let expected_rate = (borrow_rate * (PRECISION - reserve_factor)) / PRECISION;
    assert(rate == expected_rate, 'wrong deposit rate');
}

#[test]
fn test_weighted_amount_long_duration() {
    let deposit_amount: u256 = 1000000000000000000;
    let last_update_time: u64 = 0;
    let current_time: u64 = 31536000; // 1年
    let weighted_amount = calculate_weighted_amount(deposit_amount, last_update_time, current_time);
    // 长期存款应该获得更高的权重
    assert(weighted_amount > deposit_amount.into() * 2, 'long-term weight too low');
}

#[test]
fn test_weighted_amount_short_duration() {
    let deposit_amount: u256 = 1000000000000000000;
    let last_update_time: u64 = 0;
    let current_time: u64 = 3600; // 1小时
    let weighted_amount = calculate_weighted_amount(deposit_amount, last_update_time, current_time);
    // 短期存款权重增加应该较小
    assert(weighted_amount < deposit_amount.into() * 2, 'short-term weight too high');
}

#[test]
fn test_interest_calculation_one_day() {
    let principal = 1000000000000000000; // 1 ETH
    let rate = 100000000000000000; // 10%
    let time_elapsed = 86400; // 1天
    let interest = interest_rate_model_utils::calculate_interest(principal, rate, time_elapsed);
    // 验证一天的利息计算
    let expected_interest = (principal * rate * time_elapsed) / (PRECISION * SECONDS_PER_YEAR);
    assert(interest == expected_interest, 'wrong daily interest');
}

#[test]
fn test_interest_calculation_zero_time() {
    let principal = 1000000000000000000;
    let rate = 100000000000000000;
    let interest = interest_rate_model_utils::calculate_interest(principal, rate, 0);
    assert(interest == 0, 'interest should be zero');
}

#[test]
fn test_interest_calculation_zero_rate() {
    let principal = 1000000000000000000;
    let time_elapsed = 31536000;
    let interest = interest_rate_model_utils::calculate_interest(principal, 0, time_elapsed);
    assert(interest == 0, 'interest should be zero');
}

