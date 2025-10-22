-- UAF Data Preparation for TD_SMOOTHING
-- Prepares time series data for UAF Digital Signal Processing workflows
-- Focus: Signal smoothing, noise reduction, data regularization, outlier suppression

-- INSTRUCTIONS:
-- 1. Replace {USER_DATABASE} with your database name
-- 2. Replace {USER_TABLE} with your time series table name
-- 3. Replace {TIMESTAMP_COLUMN} with your time column
-- 4. Replace {VALUE_COLUMNS} with comma-separated value columns
-- 5. Configure smoothing parameters based on signal characteristics

-- ============================================================================
-- STEP 1: Raw Signal Data Preparation
-- ============================================================================

-- Load and prepare raw time series signal
DROP TABLE IF EXISTS uaf_raw_signal;
CREATE MULTISET TABLE uaf_raw_signal AS (
    SELECT
        {TIMESTAMP_COLUMN} as ts,
        {VALUE_COLUMNS} as signal_value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as time_index
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {TIMESTAMP_COLUMN} IS NOT NULL
    AND {VALUE_COLUMNS} IS NOT NULL
    ORDER BY {TIMESTAMP_COLUMN}
) WITH DATA;

-- ============================================================================
-- STEP 2: Signal Quality Assessment
-- ============================================================================

-- Assess noise level and signal characteristics
SELECT
    'Signal Quality Metrics' as MetricType,
    COUNT(*) as TotalSamples,
    AVG(signal_value) as SignalMean,
    STDDEV(signal_value) as SignalStdDev,
    MIN(signal_value) as SignalMin,
    MAX(signal_value) as SignalMax,
    -- Signal-to-noise ratio estimate
    AVG(signal_value) / NULLIFZERO(STDDEV(signal_value)) as SNR_Estimate,
    -- Coefficient of variation
    STDDEV(signal_value) / NULLIFZERO(AVG(signal_value)) as CoeffVariation
FROM uaf_raw_signal;

-- Calculate point-to-point variation (noise indicator)
SELECT
    'Point-to-Point Variation' as MetricType,
    AVG(ABS(diff)) as AvgAbsChange,
    STDDEV(diff) as StdDevChange,
    MAX(ABS(diff)) as MaxAbsChange,
    -- High variation suggests noisy signal
    CASE
        WHEN STDDEV(diff) / NULLIFZERO(AVG(ABS(diff))) > 2 THEN 'High Noise'
        WHEN STDDEV(diff) / NULLIFZERO(AVG(ABS(diff))) > 1 THEN 'Moderate Noise'
        ELSE 'Low Noise'
    END as NoiseLevel
FROM (
    SELECT
        signal_value - LAG(signal_value) OVER (ORDER BY time_index) as diff
    FROM uaf_raw_signal
) diffs
WHERE diff IS NOT NULL;

-- ============================================================================
-- STEP 3: Outlier Detection for Smoothing
-- ============================================================================

-- Detect outliers that may affect smoothing
DROP TABLE IF EXISTS signal_outliers;
CREATE MULTISET TABLE signal_outliers AS (
    SELECT
        time_index,
        ts,
        signal_value,
        mean_val,
        stddev_val,
        -- Z-score
        (signal_value - mean_val) / NULLIFZERO(stddev_val) as z_score,
        -- Outlier flags
        CASE WHEN ABS((signal_value - mean_val) / NULLIFZERO(stddev_val)) > 3 THEN 1 ELSE 0 END as is_outlier_3sigma,
        CASE WHEN ABS((signal_value - mean_val) / NULLIFZERO(stddev_val)) > 2 THEN 1 ELSE 0 END as is_outlier_2sigma
    FROM uaf_raw_signal
    CROSS JOIN (
        SELECT AVG(signal_value) as mean_val, STDDEV(signal_value) as stddev_val
        FROM uaf_raw_signal
    ) stats
) WITH DATA;

-- Outlier summary
SELECT
    'Outlier Detection Summary' as ReportType,
    COUNT(*) as TotalPoints,
    SUM(is_outlier_3sigma) as Outliers_3Sigma,
    SUM(is_outlier_2sigma) as Outliers_2Sigma,
    CAST(100.0 * SUM(is_outlier_3sigma) / COUNT(*) AS DECIMAL(5,2)) as OutlierPct_3Sigma,
    CAST(100.0 * SUM(is_outlier_2sigma) / COUNT(*) AS DECIMAL(5,2)) as OutlierPct_2Sigma
FROM signal_outliers;

-- ============================================================================
-- STEP 4: Pre-Smoothing Signal Preparation
-- ============================================================================

-- Prepare signal with outlier treatment options
DROP TABLE IF EXISTS signal_preprocessed;
CREATE MULTISET TABLE signal_preprocessed AS (
    SELECT
        s.time_index,
        s.ts,
        s.signal_value as original_signal,
        -- Option 1: Keep original value
        s.signal_value as signal_keep_outliers,
        -- Option 2: Cap outliers at 3-sigma
        CASE
            WHEN o.is_outlier_3sigma = 1 AND s.signal_value > o.mean_val THEN o.mean_val + 3 * o.stddev_val
            WHEN o.is_outlier_3sigma = 1 AND s.signal_value < o.mean_val THEN o.mean_val - 3 * o.stddev_val
            ELSE s.signal_value
        END as signal_capped,
        -- Option 3: Replace outliers with local median
        COALESCE(
            CASE WHEN o.is_outlier_3sigma = 1 THEN NULL ELSE s.signal_value END,
            MEDIAN(s.signal_value) OVER (ORDER BY s.time_index ROWS BETWEEN 5 PRECEDING AND 5 FOLLOWING)
        ) as signal_outliers_replaced,
        o.is_outlier_3sigma,
        o.z_score
    FROM uaf_raw_signal s
    INNER JOIN signal_outliers o ON s.time_index = o.time_index
) WITH DATA;

-- ============================================================================
-- STEP 5: Smoothing Window Size Determination
-- ============================================================================

-- Calculate optimal window sizes based on signal characteristics
SELECT
    'Recommended Smoothing Windows' as RecommendationType,
    -- Very short window (good for preserving detail)
    3 as window_3_detail_preserving,
    -- Short window (light smoothing)
    5 as window_5_light_smoothing,
    -- Medium window (moderate smoothing)
    10 as window_10_moderate_smoothing,
    -- Long window (heavy smoothing)
    20 as window_20_heavy_smoothing,
    -- Adaptive window (based on data size)
    CASE
        WHEN n < 100 THEN 3
        WHEN n < 500 THEN 5
        WHEN n < 1000 THEN 10
        ELSE 20
    END as adaptive_window,
    n as total_samples
FROM (SELECT COUNT(*) as n FROM uaf_raw_signal) size_info;

-- ============================================================================
-- STEP 6: Create Multiple Smoothing Baseline Comparisons
-- ============================================================================

-- Generate simple moving average baselines for comparison
DROP TABLE IF EXISTS smoothing_baselines;
CREATE MULTISET TABLE smoothing_baselines AS (
    SELECT
        time_index,
        ts,
        original_signal,
        -- Moving averages of different window sizes
        AVG(original_signal) OVER (ORDER BY time_index ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) as ma_5,
        AVG(original_signal) OVER (ORDER BY time_index ROWS BETWEEN 4 PRECEDING AND 4 FOLLOWING) as ma_9,
        AVG(original_signal) OVER (ORDER BY time_index ROWS BETWEEN 9 PRECEDING AND 9 FOLLOWING) as ma_19,
        -- Weighted moving average (center-weighted)
        (1*LAG(original_signal,2) OVER (ORDER BY time_index) +
         2*LAG(original_signal,1) OVER (ORDER BY time_index) +
         3*original_signal +
         2*LEAD(original_signal,1) OVER (ORDER BY time_index) +
         1*LEAD(original_signal,2) OVER (ORDER BY time_index)) / 9.0 as wma_5,
        -- Exponential moving average approximation
        AVG(original_signal) OVER (ORDER BY time_index ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) as ema_5_approx
    FROM signal_preprocessed
) WITH DATA;

-- ============================================================================
-- STEP 7: Smoothness Metrics Calculation
-- ============================================================================

-- Calculate smoothness improvement metrics
SELECT
    'Smoothness Comparison' as MetricType,
    -- Original signal roughness
    STDDEV(original_signal - LAG(original_signal) OVER (ORDER BY time_index)) as original_roughness,
    -- Smoothed signal roughness (MA-5)
    STDDEV(ma_5 - LAG(ma_5) OVER (ORDER BY time_index)) as ma5_roughness,
    -- Smoothed signal roughness (MA-9)
    STDDEV(ma_9 - LAG(ma_9) OVER (ORDER BY time_index)) as ma9_roughness,
    -- Smoothness improvement ratio
    STDDEV(original_signal - LAG(original_signal) OVER (ORDER BY time_index)) /
        NULLIFZERO(STDDEV(ma_5 - LAG(ma_5) OVER (ORDER BY time_index))) as smoothness_improvement_ma5
FROM smoothing_baselines;

-- ============================================================================
-- STEP 8: UAF-Ready Dataset for Smoothing
-- ============================================================================

-- Final dataset ready for TD_SMOOTHING
DROP TABLE IF EXISTS uaf_smoothing_ready;
CREATE MULTISET TABLE uaf_smoothing_ready AS (
    SELECT
        p.time_index,
        p.ts as timestamp_col,
        p.original_signal as raw_signal,
        p.signal_capped as preprocessed_signal,
        p.is_outlier_3sigma,
        p.z_score,
        b.ma_5,
        b.ma_9,
        b.wma_5,
        -- Signal characteristics for adaptive smoothing
        STDDEV(p.original_signal) OVER (ORDER BY p.time_index ROWS BETWEEN 10 PRECEDING AND 10 FOLLOWING) as local_volatility,
        -- Rate of change
        (p.original_signal - LAG(p.original_signal, 1) OVER (ORDER BY p.time_index)) /
            NULLIFZERO(LAG(p.original_signal, 1) OVER (ORDER BY p.time_index)) as rate_of_change
    FROM signal_preprocessed p
    INNER JOIN smoothing_baselines b ON p.time_index = b.time_index
    ORDER BY p.time_index
) WITH DATA;

-- Summary report
SELECT
    'Smoothing Data Preparation Summary' as ReportType,
    COUNT(*) as TotalSamples,
    SUM(is_outlier_3sigma) as OutlierCount,
    MIN(timestamp_col) as StartTime,
    MAX(timestamp_col) as EndTime,
    AVG(raw_signal) as AvgRawSignal,
    STDDEV(raw_signal) as StdDevRawSignal,
    AVG(preprocessed_signal) as AvgPreprocessedSignal,
    STDDEV(preprocessed_signal) as StdDevPreprocessedSignal
FROM uaf_smoothing_ready;

-- Export prepared data
SELECT * FROM uaf_smoothing_ready
ORDER BY time_index;

/*
SIGNAL SMOOTHING CHECKLIST:
□ Assess signal quality and noise level
□ Detect and handle outliers appropriately
□ Choose smoothing method based on signal characteristics:
  - Moving Average: Simple, preserves trends
  - Exponential Smoothing: Weights recent data more
  - Savitzky-Golay: Preserves peaks and valleys
  - Gaussian: Good for normally distributed noise
  - Median Filter: Robust to outliers

□ Select appropriate window size (trade-off: smoothness vs detail)
□ Validate smoothing preserves important signal features
□ Compare multiple smoothing approaches
□ Document preprocessing decisions

SMOOTHING TECHNIQUES:
1. Simple Moving Average (SMA): Equal weights, symmetric
2. Weighted Moving Average (WMA): Center-weighted
3. Exponential Moving Average (EMA): Recent data emphasis
4. Median Filter: Robust to impulse noise
5. Gaussian Smoothing: Smooth gradual transitions
6. Savitzky-Golay: Polynomial fitting, preserves features
7. LOWESS/LOESS: Local regression smoothing
8. Kalman Filter: State-space smoothing

SMOOTHING APPLICATIONS:
- Noise reduction in sensor data
- Trend extraction from volatile signals
- Data regularization for downstream modeling
- Outlier suppression
- Signal preprocessing for feature extraction
- Visualization enhancement
- Anomaly detection preparation

NEXT STEPS:
1. Review signal quality metrics
2. Select preprocessing strategy (keep/cap/replace outliers)
3. Choose smoothing method and window size
4. Proceed to td_smoothing_workflow.sql for UAF execution
5. Compare smoothed output with baselines
6. Validate that important signal features are preserved
*/
