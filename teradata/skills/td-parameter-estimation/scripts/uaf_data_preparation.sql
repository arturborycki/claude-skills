-- UAF Data Preparation for TD_PARAMETER_ESTIMATION
-- Prepares time series data for UAF Model Preparation workflows
-- Focus: Parameter optimization, model calibration, estimation methods, confidence intervals

-- INSTRUCTIONS:
-- 1. Replace {USER_DATABASE} with your database name
-- 2. Replace {USER_TABLE} with your time series table name
-- 3. Replace {TIMESTAMP_COLUMN} with your time column
-- 4. Replace {VALUE_COLUMNS} with comma-separated value columns
-- 5. Replace {MODEL_TABLE} with fitted model or parameters table (if applicable)

-- ============================================================================
-- STEP 1: Time Series Data Preparation
-- ============================================================================

-- Prepare base time series for parameter estimation
DROP TABLE IF EXISTS uaf_ts_base;
CREATE MULTISET TABLE uaf_ts_base AS (
    SELECT
        {TIMESTAMP_COLUMN} as ts,
        {VALUE_COLUMNS} as value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as time_index
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {TIMESTAMP_COLUMN} IS NOT NULL
    AND {VALUE_COLUMNS} IS NOT NULL
    ORDER BY {TIMESTAMP_COLUMN}
) WITH DATA;

-- ============================================================================
-- STEP 2: Train/Test Split for Parameter Estimation
-- ============================================================================

-- Split data for parameter estimation and validation
DROP TABLE IF EXISTS uaf_train_data;
CREATE MULTISET TABLE uaf_train_data AS (
    SELECT *
    FROM uaf_ts_base
    WHERE time_index <= (SELECT MAX(time_index) * 0.8 FROM uaf_ts_base)
) WITH DATA;

DROP TABLE IF EXISTS uaf_test_data;
CREATE MULTISET TABLE uaf_test_data AS (
    SELECT *
    FROM uaf_ts_base
    WHERE time_index > (SELECT MAX(time_index) * 0.8 FROM uaf_ts_base)
) WITH DATA;

-- ============================================================================
-- STEP 3: Statistical Properties for Parameter Estimation
-- ============================================================================

-- Calculate statistical moments for initial parameter estimation
SELECT
    'Training Data Statistics' as DatasetType,
    COUNT(*) as N,
    AVG(value) as Mean,
    STDDEV(value) as StdDev,
    MIN(value) as MinValue,
    MAX(value) as MaxValue,
    SKEWNESS(value) as Skewness,
    KURTOSIS(value) as Kurtosis
FROM uaf_train_data;

-- Autocorrelation structure analysis
SELECT
    lag,
    AVG((value - mean_val) * (lag_value - mean_val)) / var_val as autocorr
FROM (
    SELECT
        t1.time_index,
        t1.value,
        t2.value as lag_value,
        t1.time_index - t2.time_index as lag,
        (SELECT AVG(value) FROM uaf_train_data) as mean_val,
        (SELECT VARIANCE(value) FROM uaf_train_data) as var_val
    FROM uaf_train_data t1
    INNER JOIN uaf_train_data t2
        ON t1.time_index > t2.time_index
        AND t1.time_index - t2.time_index <= 20
) acf
GROUP BY lag
ORDER BY lag;

-- ============================================================================
-- STEP 4: Parameter Grid Preparation
-- ============================================================================

-- Create parameter grid for grid search optimization
DROP TABLE IF EXISTS parameter_grid;
CREATE MULTISET TABLE parameter_grid AS (
    SELECT
        param_id,
        param_name,
        param_value
    FROM (
        SELECT 1 as param_id, 'alpha' as param_name, 0.01 as param_value
        UNION ALL SELECT 1, 'beta', 0.01
        UNION ALL SELECT 1, 'gamma', 0.01
        UNION ALL SELECT 2, 'alpha', 0.05
        UNION ALL SELECT 2, 'beta', 0.05
        UNION ALL SELECT 2, 'gamma', 0.05
        UNION ALL SELECT 3, 'alpha', 0.10
        UNION ALL SELECT 3, 'beta', 0.10
        UNION ALL SELECT 3, 'gamma', 0.10
        UNION ALL SELECT 4, 'alpha', 0.20
        UNION ALL SELECT 4, 'beta', 0.20
        UNION ALL SELECT 4, 'gamma', 0.20
        UNION ALL SELECT 5, 'alpha', 0.30
        UNION ALL SELECT 5, 'beta', 0.30
        UNION ALL SELECT 5, 'gamma', 0.30
    ) params
) WITH DATA;

-- ============================================================================
-- STEP 5: Initial Parameter Estimation
-- ============================================================================

-- Estimate initial parameters using simple methods
DROP TABLE IF EXISTS initial_parameters;
CREATE MULTISET TABLE initial_parameters AS (
    SELECT
        'Initial Estimate' as EstimationType,
        -- Mean-based initialization
        AVG(value) as level_param,
        -- Trend estimation using linear regression
        (MAX(time_index) * SUM(time_index * value) - SUM(time_index) * SUM(value)) /
        (MAX(time_index) * SUM(time_index * time_index) - SUM(time_index) * SUM(time_index)) as trend_param,
        -- Seasonal strength (coefficient of variation)
        STDDEV(value) / NULLIFZERO(AVG(value)) as seasonal_strength,
        COUNT(*) as n_observations
    FROM uaf_train_data
) WITH DATA;

-- ============================================================================
-- STEP 6: Confidence Interval Preparation
-- ============================================================================

-- Prepare data for confidence interval calculation
DROP TABLE IF EXISTS confidence_prep;
CREATE MULTISET TABLE confidence_prep AS (
    SELECT
        time_index,
        ts,
        value,
        AVG(value) as mean_value,
        STDDEV(value) as std_dev,
        COUNT(*) OVER () as n,
        -- Calculate standard error
        STDDEV(value) / SQRT(COUNT(*) OVER ()) as standard_error
    FROM uaf_train_data
) WITH DATA;

-- Calculate confidence intervals at different levels
SELECT
    'Confidence Intervals' as MetricType,
    mean_value,
    std_dev,
    standard_error,
    -- 95% CI
    mean_value - (1.96 * standard_error) as ci_95_lower,
    mean_value + (1.96 * standard_error) as ci_95_upper,
    -- 99% CI
    mean_value - (2.576 * standard_error) as ci_99_lower,
    mean_value + (2.576 * standard_error) as ci_99_upper
FROM confidence_prep
WHERE time_index = 1;

-- ============================================================================
-- STEP 7: UAF-Ready Dataset for Parameter Estimation
-- ============================================================================

-- Final dataset ready for TD_PARAMETER_ESTIMATION
DROP TABLE IF EXISTS uaf_parameter_ready;
CREATE MULTISET TABLE uaf_parameter_ready AS (
    SELECT
        t.time_index,
        t.ts as timestamp_col,
        t.value as series_value,
        -- Add statistical features for parameter estimation
        t.value - AVG(t.value) OVER (ORDER BY t.time_index ROWS BETWEEN 10 PRECEDING AND CURRENT ROW) as detrended_value,
        STDDEV(t.value) OVER (ORDER BY t.time_index ROWS BETWEEN 10 PRECEDING AND CURRENT ROW) as local_volatility,
        -- Moving statistics
        AVG(t.value) OVER (ORDER BY t.time_index ROWS BETWEEN 5 PRECEDING AND 5 FOLLOWING) as smoothed_value
    FROM uaf_train_data t
    ORDER BY t.time_index
) WITH DATA;

-- Summary statistics
SELECT
    'Parameter Estimation Data Summary' as ReportType,
    COUNT(*) as TotalObservations,
    MIN(timestamp_col) as StartDate,
    MAX(timestamp_col) as EndDate,
    AVG(series_value) as MeanValue,
    STDDEV(series_value) as StdDevValue,
    MIN(series_value) as MinValue,
    MAX(series_value) as MaxValue
FROM uaf_parameter_ready;

-- Export prepared data
SELECT * FROM uaf_parameter_ready
ORDER BY time_index;

/*
PARAMETER ESTIMATION CHECKLIST:
□ Verify train/test split ratio (default 80/20)
□ Calculate initial parameter estimates
□ Prepare parameter grid for optimization
□ Ensure sufficient data for reliable estimation
□ Check autocorrelation structure
□ Validate statistical properties
□ Prepare confidence interval calculations
□ Document estimation methodology

ESTIMATION METHODS SUPPORTED:
- Maximum Likelihood Estimation (MLE)
- Least Squares Estimation
- Method of Moments
- Bayesian Parameter Estimation
- Gradient-based Optimization
- Grid Search Optimization

NEXT STEPS:
1. Review initial parameter estimates
2. Configure parameter bounds for optimization
3. Proceed to td_parameter_estimation_workflow.sql for UAF execution
4. Use parameter_optimization.sql for iterative refinement
5. Calculate confidence intervals for estimated parameters
*/
