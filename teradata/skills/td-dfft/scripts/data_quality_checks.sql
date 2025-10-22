-- =====================================================
-- TD_DFFT - Data Quality Checks
-- =====================================================

-- Check for missing values
SELECT
    'Missing Values' as check_name,
    COUNT(*) as total,
    SUM(CASE WHEN value_col IS NULL THEN 1 ELSE 0 END) as missing,
    CASE
        WHEN SUM(CASE WHEN value_col IS NULL THEN 1 ELSE 0 END) = 0 THEN 'PASS'
        ELSE 'FAIL - FFT requires no missing values'
    END as status
FROM {database}.dfft_input;

-- Check series length
SELECT
    'Series Length' as check_name,
    COUNT(*) as n_observations,
    POWER(2, CAST(LOG(2, COUNT(*)) AS INTEGER)) as next_power_of_2,
    CASE
        WHEN COUNT(*) = POWER(2, CAST(LOG(2, COUNT(*)) AS INTEGER)) THEN 'PASS - Power of 2'
        WHEN COUNT(*) >= 16 THEN 'ACCEPTABLE - Can pad to power of 2'
        ELSE 'WARNING - Short series'
    END as status
FROM {database}.dfft_input;

-- Check for constant values (no variation)
SELECT
    'Variation Check' as check_name,
    STDDEV(value_col) as std_dev,
    CASE
        WHEN STDDEV(value_col) > 0 THEN 'PASS - Series has variation'
        ELSE 'FAIL - Constant series (no FFT needed)'
    END as status
FROM {database}.dfft_input;

-- Check sampling regularity
WITH time_diffs AS (
    SELECT
        time_stamp - LAG(time_stamp) OVER (ORDER BY time_stamp) as time_diff
    FROM {database}.dfft_input
)
SELECT
    'Sampling Regularity' as check_name,
    COUNT(DISTINCT time_diff) as n_distinct_intervals,
    CASE
        WHEN COUNT(DISTINCT time_diff) <= 2 THEN 'PASS - Regular sampling'
        ELSE 'WARNING - Irregular sampling may affect frequency interpretation'
    END as status
FROM time_diffs
WHERE time_diff IS NOT NULL;

-- Check for outliers (may distort spectrum)
WITH stats AS (
    SELECT AVG(value_col) as mean_val, STDDEV(value_col) as std_val
    FROM {database}.dfft_input
)
SELECT
    'Outlier Check' as check_name,
    COUNT(*) as n_outliers,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'WARNING - Outliers may affect FFT results'
    END as status
FROM {database}.dfft_input, stats
WHERE ABS(value_col - mean_val) > 3 * std_val;
-- =====================================================
