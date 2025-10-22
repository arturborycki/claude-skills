-- UAF Data Preparation for TD_CROSS_VALIDATION
-- Prepares time series data for UAF Model Preparation workflows
-- Focus: Model validation, performance assessment, overfitting detection, robustness testing

-- INSTRUCTIONS:
-- 1. Replace {USER_DATABASE} with your database name
-- 2. Replace {USER_TABLE} with your time series table name
-- 3. Replace {TIMESTAMP_COLUMN} with your time column
-- 4. Replace {VALUE_COLUMNS} with comma-separated value columns
-- 5. Configure K (number of folds) based on data size and requirements

-- ============================================================================
-- STEP 1: Time Series Base Preparation
-- ============================================================================

-- Prepare chronologically ordered time series
DROP TABLE IF EXISTS uaf_cv_base;
CREATE MULTISET TABLE uaf_cv_base AS (
    SELECT
        {TIMESTAMP_COLUMN} as ts,
        {VALUE_COLUMNS} as value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as time_index,
        EXTRACT(YEAR FROM {TIMESTAMP_COLUMN}) as year,
        EXTRACT(MONTH FROM {TIMESTAMP_COLUMN}) as month,
        EXTRACT(DAY FROM {TIMESTAMP_COLUMN}) as day
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {TIMESTAMP_COLUMN} IS NOT NULL
    AND {VALUE_COLUMNS} IS NOT NULL
    ORDER BY {TIMESTAMP_COLUMN}
) WITH DATA;

-- ============================================================================
-- STEP 2: K-Fold Cross-Validation Split
-- ============================================================================

-- Create standard k-fold splits (k=5)
DROP TABLE IF EXISTS cv_kfold_splits;
CREATE MULTISET TABLE cv_kfold_splits AS (
    SELECT
        time_index,
        ts,
        value,
        CAST((time_index - 1) * 5.0 / n + 1 AS INTEGER) as fold_id,
        n as total_observations
    FROM uaf_cv_base
    CROSS JOIN (SELECT MAX(time_index) as n FROM uaf_cv_base) size_info
) WITH DATA;

-- Verify fold distribution
SELECT
    fold_id,
    COUNT(*) as FoldSize,
    MIN(ts) as FoldStartDate,
    MAX(ts) as FoldEndDate,
    AVG(value) as FoldMean,
    STDDEV(value) as FoldStdDev
FROM cv_kfold_splits
GROUP BY fold_id
ORDER BY fold_id;

-- ============================================================================
-- STEP 3: Time Series Specific Cross-Validation Splits
-- ============================================================================

-- Rolling Origin Cross-Validation (Time Series Split)
-- Progressive training windows with fixed test horizon
DROP TABLE IF EXISTS cv_rolling_origin;
CREATE MULTISET TABLE cv_rolling_origin AS (
    SELECT
        time_index,
        ts,
        value,
        CASE
            WHEN time_index <= n * 0.5 THEN 1
            WHEN time_index <= n * 0.6 THEN 2
            WHEN time_index <= n * 0.7 THEN 3
            WHEN time_index <= n * 0.8 THEN 4
            ELSE 5
        END as origin_id,
        CASE
            WHEN time_index <= n * 0.5 THEN 'train'
            WHEN time_index <= n * 0.55 THEN CASE WHEN time_index > n * 0.5 THEN 'test_fold1' ELSE 'train' END
            WHEN time_index <= n * 0.6 THEN CASE WHEN time_index > n * 0.6 - n * 0.05 THEN 'test_fold2' ELSE 'train' END
            WHEN time_index <= n * 0.7 THEN CASE WHEN time_index > n * 0.7 - n * 0.05 THEN 'test_fold3' ELSE 'train' END
            WHEN time_index <= n * 0.8 THEN CASE WHEN time_index > n * 0.8 - n * 0.05 THEN 'test_fold4' ELSE 'train' END
            ELSE 'test_fold5'
        END as split_type
    FROM uaf_cv_base
    CROSS JOIN (SELECT MAX(time_index) as n FROM uaf_cv_base) size_info
) WITH DATA;

-- ============================================================================
-- STEP 4: Blocked Cross-Validation for Time Series
-- ============================================================================

-- Create blocked folds to preserve temporal structure
-- Blocks avoid data leakage from correlated adjacent observations
DROP TABLE IF EXISTS cv_blocked_splits;
CREATE MULTISET TABLE cv_blocked_splits AS (
    SELECT
        time_index,
        ts,
        value,
        CAST((time_index - 1) / block_size AS INTEGER) as block_id,
        MOD(CAST((time_index - 1) / block_size AS INTEGER), 5) + 1 as fold_id
    FROM uaf_cv_base
    CROSS JOIN (
        SELECT CAST(MAX(time_index) / 25.0 AS INTEGER) as block_size
        FROM uaf_cv_base
    ) block_params
) WITH DATA;

-- ============================================================================
-- STEP 5: Expanding Window Cross-Validation
-- ============================================================================

-- Expanding training window with fixed-size test sets
DROP TABLE IF EXISTS cv_expanding_window;
CREATE MULTISET TABLE cv_expanding_window AS (
    SELECT
        time_index,
        ts,
        value,
        CASE
            WHEN time_index <= n * 0.5 THEN 1
            WHEN time_index <= n * 0.6 THEN 2
            WHEN time_index <= n * 0.7 THEN 3
            WHEN time_index <= n * 0.8 THEN 4
            WHEN time_index <= n * 0.9 THEN 5
            ELSE 6
        END as window_id,
        CASE
            -- Window 1: train on first 50%, test on next 10%
            WHEN time_index <= n * 0.5 THEN 'train_w1'
            WHEN time_index <= n * 0.6 THEN 'test_w1'
            -- Window 2: train on first 60%, test on next 10%
            WHEN time_index <= n * 0.7 THEN CASE WHEN time_index <= n * 0.6 THEN 'train_w2' ELSE 'test_w2' END
            -- Window 3: train on first 70%, test on next 10%
            WHEN time_index <= n * 0.8 THEN CASE WHEN time_index <= n * 0.7 THEN 'train_w3' ELSE 'test_w3' END
            -- Window 4: train on first 80%, test on next 10%
            WHEN time_index <= n * 0.9 THEN CASE WHEN time_index <= n * 0.8 THEN 'train_w4' ELSE 'test_w4' END
            -- Window 5: train on first 90%, test on last 10%
            ELSE CASE WHEN time_index <= n * 0.9 THEN 'train_w5' ELSE 'test_w5' END
        END as split_label
    FROM uaf_cv_base
    CROSS JOIN (SELECT MAX(time_index) as n FROM uaf_cv_base) size_info
) WITH DATA;

-- ============================================================================
-- STEP 6: Overfitting Detection Metrics Preparation
-- ============================================================================

-- Calculate train vs test performance gaps for overfitting detection
DROP TABLE IF EXISTS overfitting_metrics_template;
CREATE MULTISET TABLE overfitting_metrics_template (
    model_id VARCHAR(50),
    fold_id INTEGER,
    train_mse DECIMAL(18,6),
    test_mse DECIMAL(18,6),
    train_mae DECIMAL(18,6),
    test_mae DECIMAL(18,6),
    train_r_squared DECIMAL(18,6),
    test_r_squared DECIMAL(18,6),
    -- Overfitting indicators
    mse_gap DECIMAL(18,6),
    mae_gap DECIMAL(18,6),
    r_squared_gap DECIMAL(18,6),
    is_overfitting INTEGER,
    created_timestamp TIMESTAMP
);

-- ============================================================================
-- STEP 7: Cross-Validation Performance Aggregation Template
-- ============================================================================

-- Template for aggregating CV results across folds
DROP TABLE IF EXISTS cv_performance_summary;
CREATE MULTISET TABLE cv_performance_summary (
    model_id VARCHAR(50),
    cv_method VARCHAR(50),
    n_folds INTEGER,
    -- Average metrics
    mean_test_mse DECIMAL(18,6),
    std_test_mse DECIMAL(18,6),
    mean_test_mae DECIMAL(18,6),
    std_test_mae DECIMAL(18,6),
    mean_test_r_squared DECIMAL(18,6),
    std_test_r_squared DECIMAL(18,6),
    -- Stability metrics
    cv_score DECIMAL(18,6),
    stability_index DECIMAL(18,6),
    -- Overfitting assessment
    avg_overfitting_gap DECIMAL(18,6),
    overfitting_detected INTEGER,
    created_timestamp TIMESTAMP
);

-- ============================================================================
-- STEP 8: UAF-Ready Cross-Validation Dataset
-- ============================================================================

-- Final dataset ready for TD_CROSS_VALIDATION
DROP TABLE IF EXISTS uaf_cv_ready;
CREATE MULTISET TABLE uaf_cv_ready AS (
    SELECT
        kf.time_index,
        kf.ts as timestamp_col,
        kf.value as series_value,
        kf.fold_id as kfold_id,
        ro.origin_id,
        ro.split_type as rolling_split,
        bk.block_id,
        bk.fold_id as blocked_fold_id,
        ew.window_id,
        ew.split_label as expanding_split
    FROM cv_kfold_splits kf
    INNER JOIN cv_rolling_origin ro ON kf.time_index = ro.time_index
    INNER JOIN cv_blocked_splits bk ON kf.time_index = bk.time_index
    INNER JOIN cv_expanding_window ew ON kf.time_index = ew.time_index
    ORDER BY kf.time_index
) WITH DATA;

-- Summary statistics
SELECT
    'Cross-Validation Data Summary' as ReportType,
    COUNT(*) as TotalObservations,
    COUNT(DISTINCT kfold_id) as NumKFolds,
    COUNT(DISTINCT origin_id) as NumRollingOrigins,
    COUNT(DISTINCT window_id) as NumExpandingWindows,
    MIN(timestamp_col) as StartDate,
    MAX(timestamp_col) as EndDate,
    AVG(series_value) as MeanValue,
    STDDEV(series_value) as StdDevValue
FROM uaf_cv_ready;

-- K-fold distribution check
SELECT
    kfold_id,
    COUNT(*) as FoldSize,
    AVG(series_value) as FoldMean,
    STDDEV(series_value) as FoldStdDev,
    MIN(timestamp_col) as FoldStart,
    MAX(timestamp_col) as FoldEnd
FROM uaf_cv_ready
GROUP BY kfold_id
ORDER BY kfold_id;

-- Export prepared data
SELECT * FROM uaf_cv_ready
ORDER BY time_index;

/*
CROSS-VALIDATION STRATEGY CHECKLIST:
□ Choose appropriate CV method for time series:
  - K-Fold: Use for large datasets with minimal temporal dependence
  - Rolling Origin: Best for strict temporal validation
  - Blocked: Prevents temporal data leakage
  - Expanding Window: Simulates operational forecasting

□ Verify fold sizes are balanced and sufficient
□ Ensure test sets respect temporal ordering
□ Check for data leakage between train and test
□ Configure number of folds based on data size
□ Set up overfitting detection metrics
□ Plan computational resources (CV is computationally intensive)

OVERFITTING DETECTION INDICATORS:
- Train error << Test error (significant gap)
- High variance across CV folds
- Performance degradation on unseen data
- Model complexity disproportionate to data size
- Perfect training set performance
- Unstable predictions across folds

CROSS-VALIDATION METHODS:
1. K-Fold: Standard validation, use with caution for time series
2. Rolling Origin: Forward-chaining, respects temporal order
3. Blocked: Reduces temporal correlation in folds
4. Expanding Window: Most realistic operational scenario

NEXT STEPS:
1. Select appropriate CV strategy for your use case
2. Review fold distributions and balance
3. Proceed to td_cross_validation_workflow.sql for UAF execution
4. Monitor training and test performance gaps
5. Aggregate results across folds for robust model assessment
6. Detect and address overfitting if present
*/
