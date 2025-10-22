-- =====================================================
-- TD_ARIMA - Data Quality Checks
-- =====================================================

-- Check 1: Missing values
SELECT
    'Missing Values Check' as check_name,
    COUNT(*) as total_records,
    SUM(CASE WHEN value_col IS NULL THEN 1 ELSE 0 END) as missing_values,
    CASE
        WHEN SUM(CASE WHEN value_col IS NULL THEN 1 ELSE 0 END) = 0 THEN 'PASS'
        ELSE 'FAIL - Missing values present'
    END as status
FROM {database}.arima_input;

-- Check 2: Time series length
SELECT
    'Series Length Check' as check_name,
    COUNT(*) as n_observations,
    CASE
        WHEN COUNT(*) >= 50 THEN 'PASS - Sufficient data'
        WHEN COUNT(*) >= 30 THEN 'WARNING - Short series'
        ELSE 'FAIL - Insufficient data (<30)'
    END as status
FROM {database}.arima_input;

-- Check 3: Time gaps
WITH time_gaps AS (
    SELECT
        time_stamp,
        LAG(time_stamp) OVER (ORDER BY time_stamp) as prev_time,
        time_stamp - LAG(time_stamp) OVER (ORDER BY time_stamp) as gap
    FROM {database}.arima_input
)
SELECT
    'Time Gap Check' as check_name,
    COUNT(DISTINCT gap) as n_distinct_intervals,
    MIN(gap) as min_gap,
    MAX(gap) as max_gap,
    CASE
        WHEN COUNT(DISTINCT gap) <= 2 THEN 'PASS - Regular intervals'
        ELSE 'WARNING - Irregular intervals'
    END as status
FROM time_gaps
WHERE gap IS NOT NULL;

-- Check 4: Outliers
WITH stats AS (
    SELECT
        AVG(value_col) as mean_val,
        STDDEV(value_col) as std_val
    FROM {database}.arima_input
)
SELECT
    'Outlier Check' as check_name,
    COUNT(*) as n_outliers,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {database}.arima_input) AS DECIMAL(5,2)) as outlier_pct,
    CASE
        WHEN COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {database}.arima_input) < 5 THEN 'PASS - Few outliers'
        ELSE 'WARNING - Many outliers (>5%)'
    END as status
FROM {database}.arima_input, stats
WHERE ABS(value_col - mean_val) > 3 * std_val;

-- Check 5: Trend and seasonality (visual check)
WITH moving_avg AS (
    SELECT
        time_stamp,
        value_col,
        AVG(value_col) OVER (ORDER BY time_stamp ROWS BETWEEN 5 PRECEDING AND 5 FOLLOWING) as ma,
        value_col - AVG(value_col) OVER (ORDER BY time_stamp ROWS BETWEEN 5 PRECEDING AND 5 FOLLOWING) as detrended
    FROM {database}.arima_input
)
SELECT
    'Trend Check' as check_name,
    STDDEV(ma) as trend_variability,
    STDDEV(detrended) as noise_variability,
    CASE
        WHEN STDDEV(ma) > STDDEV(detrended) THEN 'Strong trend present'
        ELSE 'Weak or no trend'
    END as trend_assessment
FROM moving_avg;
-- =====================================================
