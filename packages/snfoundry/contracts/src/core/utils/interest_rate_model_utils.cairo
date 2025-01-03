pub mod interest_rate_model_utils {
    const PRECISION: u256 = 1000000000000000000; // 1e18
    const BASE_RATE: u256 = 20000000000000000; // 2%
    const OPTIMAL_RATE: u256 = 80000000000000000; // 8%
    const EXCESS_RATE: u256 = 1000000000000000000; // 100%
    const OPTIMAL_UTILIZATION: u256 = 800000000000000000; // 80%
    const SECONDS_PER_YEAR: u256 = 31536000; // 每年秒数

    // 预计算常量
    const RATE_SPREAD: u256 = OPTIMAL_RATE - BASE_RATE; // 利率差值
    const EXCESS_SPREAD: u256 = EXCESS_RATE - OPTIMAL_RATE; // 超额利率差值
    const UTILIZATION_SCALE: u256 = PRECISION / OPTIMAL_UTILIZATION; // 利用率比例

    #[derive(Drop)]
    pub mod Errors {
        pub const DEPOSITS_TOO_LARGE: felt252 = 'IRM: deposits too large';
        pub const BORROWS_EXCEED_DEPOSITS: felt252 = 'IRM: borrows exceed deposits';
    }

    /// @notice 计算存款利率
    /// @param total_borrows 总借款金额
    /// @param total_deposits 总存款金额
    /// @param reserve_factor 储备金率
    /// @return 存款年化利率 (以 1e18 为基数)
    pub fn calculate_deposit_rate(
        total_borrows: u256, total_deposits: u256, reserve_factor: u256,
    ) -> u256 {
        // 获取借款利率
        let borrow_rate = calculate_interest_rate(total_borrows, total_deposits);

        // 存款利率 = 借款利率 * 利用率 * (1 - 储备金率)
        let utilization = calculate_utilization(total_borrows, total_deposits);
        (borrow_rate * utilization * (PRECISION - reserve_factor)) / (PRECISION * PRECISION)
    }

    /// @notice 计算借贷利率
    /// @param total_borrows 总借款金额
    /// @param total_deposits 总存款金额
    /// @return 年化利率 (以 1e18 为基数)
    pub fn calculate_interest_rate(total_borrows: u256, total_deposits: u256) -> u256 {
        // 早期返回检查
        if total_deposits == 0 || total_borrows == 0 {
            return BASE_RATE;
        }

        // 安全性检查
        assert(total_borrows <= total_deposits, Errors::BORROWS_EXCEED_DEPOSITS);

        // 计算利用率
        let utilization = (total_borrows * PRECISION) / total_deposits;

        // 根据利用率计算利率
        if utilization <= OPTIMAL_UTILIZATION {
            calculate_normal_rate(utilization)
        } else {
            calculate_excess_rate(utilization)
        }
    }

    /// @notice 计算资金利用率
    /// @param total_borrows 总借款金额
    /// @param total_deposits 总存款金额
    /// @return 资金利用率 (以 1e18 为基数)
    pub fn calculate_utilization(total_borrows: u256, total_deposits: u256) -> u256 {
        if total_deposits == 0 {
            return 0;
        }
        (total_borrows * PRECISION) / total_deposits
    }

    /// @notice 计算累积利息
    /// @param principal 本金
    /// @param rate 年化利率
    /// @param time_elapsed 经过时间(秒)
    /// @return 累积的利息
    pub fn calculate_interest(principal: u256, rate: u256, time_elapsed: u256) -> u256 {
        (principal * rate * time_elapsed) / (PRECISION * SECONDS_PER_YEAR)
    }

    /// @dev 计算正常利率区间的利率
    fn calculate_normal_rate(utilization: u256) -> u256 {
        BASE_RATE + ((RATE_SPREAD * utilization) / OPTIMAL_UTILIZATION)
    }

    /// @dev 计算超额利率区间的利率
    fn calculate_excess_rate(utilization: u256) -> u256 {
        // 1. 计算超额利用率（以20%为基数）
        // 例如：85%利用率时，超额部分为 5%
        let excess_utilization = utilization - OPTIMAL_UTILIZATION;
        // 2. 计算在超额区间的位置（0-20%映射到0-100%）
        // 超额区间总长度为 20%（100% - 80%）
        let remaining_utilization = PRECISION - OPTIMAL_UTILIZATION;
        // 3. 计算超额利率
        // EXCESS_SPREAD = 92%（100% - 8%）
        // 在85%利用率时：(0.05e18 * 0.92e18) / 0.2e18 = 0.23e18
        // 最终利率：8% + 22% = 30%
        let additional_rate = (excess_utilization * EXCESS_SPREAD) / remaining_utilization;
        OPTIMAL_RATE + additional_rate
    }
}
