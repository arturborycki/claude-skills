-- UAF Data Preparation for TD_MODEL_SELECTION
-- Prepares time series data for UAF Model Preparation workflows
-- Focus: Model comparison, automated selection, performance evaluation, best model identification

-- INSTRUCTIONS:
-- 1. Replace {USER_DATABASE} with your database name
-- 2. Replace {USER_TABLE} with your time series table name
-- 3. Replace {TIMESTAMP_COLUMN} with your time column
-- 4. Replace {VALUE_COLUMNS} with comma-separated value columns
-- 5. Replace {ID_COLUMN} with series identifier if multiple time series

-- ============================================================================
-- STEP 1: Multi-Series Time Series Preparation
-- ============================================================================

-- Prepare time series data with series identifiers
DROP TABLE IF EXISTS uaf_multimodel_base;
CREATE MULTISET TABLE uaf_multimodel_base AS (
    SELECT
        {TIMESTAMP_COLUMN} as ts,
        {VALUE_COLUMNS} as value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as time_index,
        -- Add series features for model differentiation
        EXTRACT(YEAR FROM {TIMESTAMP_COLUMN}) as year,
        EXTRACT(MONTH FROM {TIMESTAMP_COLUMN}) as month,
        CASE WHEN EXTRACT(DOW FROM {TIMESTAMP_COLUMN}) IN (0, 6) THEN 1 ELSE 0 END as is_weekend
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {TIMESTAMP_COLUMN} IS NOT NULL
    AND {VALUE_COLUMNS} IS NOT NULL
    ORDER BY {TIMESTAMP_COLUMN}
) WITH DATA;

-- ============================================================================
-- STEP 2: Train/Validation/Test Split for Model Selection
-- ============================================================================

-- Split data into train (60%), validation (20%), test (20%)
DROP TABLE IF EXISTS model_selection_train;
CREATE MULTISET TABLE model_selection_train AS (
    SELECT *
    FROM uaf_multimodel_base
    WHERE time_index <= (SELECT MAX(time_index) * 0.6 FROM uaf_multimodel_base)
) WITH DATA;

DROP TABLE IF EXISTS model_selection_validation;
CREATE MULTISET TABLE model_selection_validation AS (
    SELECT *
    FROM uaf_multimodel_base
    WHERE time_index > (SELECT MAX(time_index) * 0.6 FROM uaf_multimodel_base)
    AND time_index <= (SELECT MAX(time_index) * 0.8 FROM uaf_multimodel_base)
) WITH DATA;

DROP TABLE IF EXISTS model_selection_test;
CREATE MULTISET TABLE model_selection_test AS (
    SELECT *
    FROM uaf_multimodel_base
    WHERE time_index > (SELECT MAX(time_index) * 0.8 FROM uaf_multimodel_base)
) WITH DATA;

-- ============================================================================
-- STEP 3: Time Series Characteristics Analysis
-- ============================================================================

-- Analyze time series patterns for model selection
DROP TABLE IF EXISTS ts_characteristics;
CREATE MULTISET TABLE ts_characteristics AS (
    SELECT
        'Training Set' as DatasetType,
        COUNT(*) as N,
        AVG(value) as Mean,
        STDDEV(value) as StdDev,
        MIN(value) as MinValue,
        MAX(value) as MaxValue,
        -- Trend indicator
        CORR(time_index, value) as TrendCorrelation,
        -- Volatility
        STDDEV(value) / NULLIFZERO(AVG(value)) as CoeffVariation,
        -- Stationarity indicator (simplified)
        CASE
            WHEN STDDEV(value) / NULLIFZERO(AVG(value)) < 0.1 THEN 'Low Volatility'
            WHEN STDDEV(value) / NULLIFZERO(AVG(value)) < 0.5 THEN 'Medium Volatility'
            ELSE 'High Volatility'
        END as VolatilityClass
    FROM model_selection_train
) WITH DATA;

-- ============================================================================
-- STEP 4: Model Candidate Features Preparation
-- ============================================================================

-- Create feature set for different model types
DROP TABLE IF EXISTS model_features;
CREATE MULTISET TABLE model_features AS (
    SELECT
        time_index,
        ts,
        value as original_value,
        -- Linear model features
        time_index as linear_trend,
        -- Exponential smoothing features
        AVG(value) OVER (ORDER BY time_index ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) as ma5,
        AVG(value) OVER (ORDER BY time_index ROWS BETWEEN 10 PRECEDING AND CURRENT ROW) as ma10,
        -- ARIMA-ready features
        value - LAG(value, 1) OVER (ORDER BY time_index) as diff1,
        value - LAG(value, 12) OVER (ORDER BY time_index) as seasonal_diff12,
        -- Seasonal indicators
        month,
        is_weekend,
        -- Holiday indicator (placeholder - customize based on domain)
        CASE WHEN month = 12 AND EXTRACT(DAY FROM ts) BETWEEN 20 AND 31 THEN 1 ELSE 0 END as is_holiday_period
    FROM model_selection_train
) WITH DATA;

-- ============================================================================
-- STEP 5: Model Comparison Metrics Preparation
-- ============================================================================

-- Create structure for storing model performance metrics
DROP TABLE IF EXISTS model_performance_template;
CREATE MULTISET TABLE model_performance_template (
    model_id VARCHAR(50),
    model_type VARCHAR(100),
    dataset_type VARCHAR(20),
    n_parameters INTEGER,
    aic DECIMAL(18,4),
    bic DECIMAL(18,4),
    mse DECIMAL(18,6),
    rmse DECIMAL(18,6),
    mae DECIMAL(18,6),
    mape DECIMAL(18,6),
    r_squared DECIMAL(18,6),
    adjusted_r_squared DECIMAL(18,6),
    log_likelihood DECIMAL(18,4),
    training_time_sec DECIMAL(10,2),
    created_timestamp TIMESTAMP
);

-- ============================================================================
-- STEP 6: Cross-Validation Folds Preparation
-- ============================================================================

-- Create k-fold indices for cross-validation (k=5)
DROP TABLE IF EXISTS cv_folds;
CREATE MULTISET TABLE cv_folds AS (
    SELECT
        time_index,
        ts,
        value,
        CASE
            WHEN time_index <= n * 0.2 THEN 1
            WHEN time_index <= n * 0.4 THEN 2
            WHEN time_index <= n * 0.6 THEN 3
            WHEN time_index <= n * 0.8 THEN 4
            ELSE 5
        END as fold_id
    FROM model_selection_train
    CROSS JOIN (SELECT MAX(time_index) as n FROM model_selection_train) max_idx
) WITH DATA;

-- ============================================================================
-- STEP 7: Model Candidate Registry
-- ============================================================================

-- Define candidate models for comparison
DROP TABLE IF EXISTS model_candidates;
CREATE MULTISET TABLE model_candidates (
    model_id VARCHAR(50),
    model_type VARCHAR(100),
    model_description VARCHAR(500),
    complexity_score INTEGER,
    requires_stationarity INTEGER,
    handles_seasonality INTEGER,
    parameter_count INTEGER
);

INSERT INTO model_candidates VALUES
    ('M001', 'Exponential Smoothing (Simple)', 'Single exponential smoothing for non-seasonal data', 1, 0, 0, 1),
    ('M002', 'Holt Linear', 'Double exponential smoothing with trend', 2, 0, 0, 2),
    ('M003', 'Holt-Winters Additive', 'Triple exponential smoothing with additive seasonality', 3, 0, 1, 3),
    ('M004', 'Holt-Winters Multiplicative', 'Triple exponential smoothing with multiplicative seasonality', 3, 0, 1, 3),
    ('M005', 'ARIMA(1,0,0)', 'AR(1) model for stationary data', 2, 1, 0, 2),
    ('M006', 'ARIMA(1,1,1)', 'Standard ARIMA with differencing', 3, 0, 0, 3),
    ('M007', 'SARIMA(1,1,1)(1,1,1,12)', 'Seasonal ARIMA with 12-period seasonality', 5, 0, 1, 7),
    ('M008', 'Moving Average', 'Simple moving average baseline', 1, 0, 0, 1),
    ('M009', 'Linear Trend', 'Linear regression with time trend', 1, 0, 0, 2),
    ('M010', 'Seasonal Naive', 'Naive forecast with seasonal lag', 1, 0, 1, 1);

-- ============================================================================
-- STEP 8: UAF-Ready Dataset for Model Selection
-- ============================================================================

-- Final dataset ready for TD_MODEL_SELECTION
DROP TABLE IF EXISTS uaf_model_selection_ready;
CREATE MULTISET TABLE uaf_model_selection_ready AS (
    SELECT
        time_index,
        ts as timestamp_col,
        value as series_value,
        linear_trend,
        ma5,
        ma10,
        diff1,
        seasonal_diff12,
        month,
        is_weekend,
        is_holiday_period,
        'train' as dataset_type
    FROM model_features
    WHERE diff1 IS NOT NULL AND seasonal_diff12 IS NOT NULL
    ORDER BY time_index
) WITH DATA;

-- Summary report
SELECT
    'Model Selection Data Summary' as ReportType,
    COUNT(*) as TotalObservations,
    (SELECT COUNT(*) FROM model_selection_train) as TrainSize,
    (SELECT COUNT(*) FROM model_selection_validation) as ValidationSize,
    (SELECT COUNT(*) FROM model_selection_test) as TestSize,
    (SELECT COUNT(*) FROM model_candidates) as CandidateModels,
    MIN(timestamp_col) as StartDate,
    MAX(timestamp_col) as EndDate
FROM uaf_model_selection_ready;

-- Export prepared data
SELECT * FROM uaf_model_selection_ready
ORDER BY time_index;

/*
MODEL SELECTION CHECKLIST:
□ Verify train/validation/test split (60/20/20)
□ Prepare features for different model families
□ Register candidate models in model_candidates table
□ Set up cross-validation folds for robust comparison
□ Initialize model_performance_template for results
□ Ensure sufficient data for each model type
□ Document model assumptions and requirements
□ Prepare baseline models for comparison

MODEL COMPARISON CRITERIA:
- AIC (Akaike Information Criterion) - Lower is better
- BIC (Bayesian Information Criterion) - Lower is better
- Cross-validation error - Lower is better
- Out-of-sample forecast accuracy
- Model complexity vs performance trade-off
- Computational efficiency
- Interpretability and explainability

NEXT STEPS:
1. Review time series characteristics
2. Evaluate candidate model list
3. Proceed to td_model_selection_workflow.sql for UAF execution
4. Use parameter_optimization.sql for each candidate model
5. Compare models using AIC, BIC, and CV error
6. Select best model based on validation performance
*/
