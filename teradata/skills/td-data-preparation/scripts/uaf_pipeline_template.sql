-- UAF Pipeline Template for TD_DATA_PREPARATION
-- Multi-function workflow integrating data preparation with model preparation pipeline
-- Demonstrates end-to-end UAF workflow from raw data to model-ready datasets

-- INSTRUCTIONS:
-- 1. Replace {USER_DATABASE}, {USER_TABLE}, {TIMESTAMP_COLUMN}, {VALUE_COLUMNS}
-- 2. Configure pipeline stages based on your requirements
-- 3. Adjust UAF function parameters from optimization results
-- 4. Execute pipeline stages sequentially

-- ============================================================================
-- PIPELINE OVERVIEW
-- ============================================================================
/*
This pipeline demonstrates integration of TD_DATA_PREPARATION with:
1. Data validation and quality checks
2. Time series preparation and formatting
3. Parameter optimization
4. Model selection and validation
5. Cross-validation
6. Performance monitoring

Pipeline Stages:
Stage 1: Raw Data → Data Preparation → Prepared Data
Stage 2: Prepared Data → Parameter Estimation → Estimated Parameters
Stage 3: Prepared Data + Parameters → Model Selection → Best Model
Stage 4: Best Model → Cross-Validation → Validation Results
Stage 5: Validation Results → Portmanteau Test → Model Diagnostics
Stage 6: All Results → Performance Monitoring → Production Deployment
*/

-- ============================================================================
-- STAGE 1: DATA PREPARATION
-- ============================================================================

-- 1.1: Load and validate raw time series data
DROP TABLE IF EXISTS pipeline_raw_data;
CREATE MULTISET TABLE pipeline_raw_data AS (
    SELECT
        {TIMESTAMP_COLUMN} as ts,
        {VALUE_COLUMNS} as value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as time_index
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {TIMESTAMP_COLUMN} IS NOT NULL
) WITH DATA;

-- 1.2: Execute TD_DATA_PREPARATION with optimal parameters
DROP TABLE IF EXISTS pipeline_prepared_data;
CREATE MULTISET TABLE pipeline_prepared_data AS (
    SELECT * FROM TD_DATA_PREPARATION (
        ON pipeline_raw_data
        USING
        TimeColumn ('ts')
        ValueColumn ('value')
        ValidationType ('moderate')  -- From parameter optimization
        FillMethod ('linear_interpolation')  -- From parameter optimization
        OutlierThreshold (3.0)  -- From parameter optimization
    ) AS dt
) WITH DATA;

-- ============================================================================
-- STAGE 2: FEATURE ENGINEERING FOR MODELING
-- ============================================================================

-- 2.1: Create lagged features
DROP TABLE IF EXISTS pipeline_features;
CREATE MULTISET TABLE pipeline_features AS (
    SELECT
        time_index,
        ts,
        value,
        -- Lagged values
        LAG(value, 1) OVER (ORDER BY time_index) as lag1,
        LAG(value, 7) OVER (ORDER BY time_index) as lag7,
        LAG(value, 30) OVER (ORDER BY time_index) as lag30,
        -- Moving statistics
        AVG(value) OVER (ORDER BY time_index ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as ma7,
        STDDEV(value) OVER (ORDER BY time_index ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) as volatility30,
        -- Trend
        value - LAG(value, 1) OVER (ORDER BY time_index) as diff1,
        -- Temporal features
        EXTRACT(MONTH FROM ts) as month,
        EXTRACT(DOW FROM ts) as day_of_week
    FROM pipeline_prepared_data
) WITH DATA;

-- ============================================================================
-- STAGE 3: TRAIN/VALIDATION/TEST SPLIT
-- ============================================================================

-- 3.1: Split data for modeling
DROP TABLE IF EXISTS pipeline_train;
CREATE MULTISET TABLE pipeline_train AS (
    SELECT * FROM pipeline_features
    WHERE time_index <= (SELECT MAX(time_index) * 0.7 FROM pipeline_features)
) WITH DATA;

DROP TABLE IF EXISTS pipeline_validation;
CREATE MULTISET TABLE pipeline_validation AS (
    SELECT * FROM pipeline_features
    WHERE time_index > (SELECT MAX(time_index) * 0.7 FROM pipeline_features)
    AND time_index <= (SELECT MAX(time_index) * 0.85 FROM pipeline_features)
) WITH DATA;

DROP TABLE IF EXISTS pipeline_test;
CREATE MULTISET TABLE pipeline_test AS (
    SELECT * FROM pipeline_features
    WHERE time_index > (SELECT MAX(time_index) * 0.85 FROM pipeline_features)
) WITH DATA;

-- ============================================================================
-- STAGE 4: PARAMETER ESTIMATION (OPTIONAL - IF USING TD_PARAMETER_ESTIMATION)
-- ============================================================================

-- 4.1: Estimate model parameters
-- DROP TABLE IF EXISTS pipeline_estimated_parameters;
-- CREATE MULTISET TABLE pipeline_estimated_parameters AS (
--     SELECT * FROM TD_PARAMETER_ESTIMATION (
--         ON pipeline_train
--         USING
--         EstimationMethod ('MLE')  -- From parameter optimization
--         ConfidenceLevel (0.95)
--         MaxIterations (200)
--     ) AS dt
-- ) WITH DATA;

-- ============================================================================
-- STAGE 5: MODEL SELECTION (OPTIONAL - IF USING TD_MODEL_SELECTION)
-- ============================================================================

-- 5.1: Compare candidate models
-- DROP TABLE IF EXISTS pipeline_model_comparison;
-- CREATE MULTISET TABLE pipeline_model_comparison AS (
--     SELECT * FROM TD_MODEL_SELECTION (
--         ON pipeline_train
--         USING
--         SelectionCriteria ('AIC')  -- From parameter optimization
--         ModelTypes ('ARIMA', 'ETS', 'PROPHET')
--         CrossValidation (TRUE)
--     ) AS dt
-- ) WITH DATA;

-- ============================================================================
-- STAGE 6: CROSS-VALIDATION (OPTIONAL - IF USING TD_CROSS_VALIDATION)
-- ============================================================================

-- 6.1: Perform time series cross-validation
-- DROP TABLE IF EXISTS pipeline_cv_results;
-- CREATE MULTISET TABLE pipeline_cv_results AS (
--     SELECT * FROM TD_CROSS_VALIDATION (
--         ON pipeline_train
--         USING
--         CVMethod ('time_series_split')  -- From parameter optimization
--         FoldCount (5)
--         TestSize (0.20)
--         StepAhead (1)
--     ) AS dt
-- ) WITH DATA;

-- ============================================================================
-- STAGE 7: MODEL TRAINING AND PREDICTION
-- ============================================================================

-- 7.1: Train final model (placeholder - use actual UAF forecasting function)
DROP TABLE IF EXISTS pipeline_predictions;
CREATE MULTISET TABLE pipeline_predictions AS (
    SELECT
        t.time_index,
        t.ts,
        t.value as actual,
        -- Simple baseline: moving average prediction
        AVG(h.value) as predicted
    FROM pipeline_test t
    LEFT JOIN pipeline_train h
        ON h.time_index <= t.time_index
    GROUP BY t.time_index, t.ts, t.value
) WITH DATA;

-- ============================================================================
-- STAGE 8: RESIDUAL DIAGNOSTICS (OPTIONAL - IF USING TD_PORTMAN)
-- ============================================================================

-- 8.1: Calculate residuals
DROP TABLE IF EXISTS pipeline_residuals;
CREATE MULTISET TABLE pipeline_residuals AS (
    SELECT
        time_index,
        ts,
        actual - predicted as residual
    FROM pipeline_predictions
    WHERE predicted IS NOT NULL
) WITH DATA;

-- 8.2: Portmanteau test on residuals
-- DROP TABLE IF EXISTS pipeline_diagnostics;
-- CREATE MULTISET TABLE pipeline_diagnostics AS (
--     SELECT * FROM TD_PORTMAN (
--         ON pipeline_residuals
--         USING
--         Lags (10)  -- From parameter optimization
--         ConfidenceLevel (0.95)
--         TestType ('ljung_box')
--     ) AS dt
-- ) WITH DATA;

-- ============================================================================
-- STAGE 9: PERFORMANCE EVALUATION
-- ============================================================================

-- 9.1: Calculate error metrics
SELECT
    'Pipeline Performance Summary' as ReportType,
    COUNT(*) as TotalPredictions,
    -- RMSE
    SQRT(AVG((actual - predicted) * (actual - predicted))) as RMSE,
    -- MAE
    AVG(ABS(actual - predicted)) as MAE,
    -- MAPE
    AVG(ABS((actual - predicted) / NULLIFZERO(actual)) * 100) as MAPE,
    -- Bias
    AVG(actual - predicted) as MeanBias,
    -- R-squared
    1 - (SUM((actual - predicted) * (actual - predicted)) /
         NULLIFZERO(SUM((actual - AVG(actual) OVER ()) * (actual - AVG(actual) OVER ())))) as R_Squared
FROM pipeline_predictions
WHERE predicted IS NOT NULL;

-- ============================================================================
-- STAGE 10: PIPELINE METADATA AND TRACKING
-- ============================================================================

-- 10.1: Create pipeline execution log
DROP TABLE IF EXISTS pipeline_execution_log;
CREATE MULTISET TABLE pipeline_execution_log (
    pipeline_id VARCHAR(100),
    stage_name VARCHAR(100),
    stage_status VARCHAR(50),
    records_processed INTEGER,
    execution_time_sec DECIMAL(10,2),
    error_message VARCHAR(5000),
    created_timestamp TIMESTAMP
);

-- Log pipeline stages
INSERT INTO pipeline_execution_log VALUES
    ('PIPELINE_001', 'Data Preparation', 'COMPLETED',
     (SELECT COUNT(*) FROM pipeline_prepared_data), 10.5, NULL, CURRENT_TIMESTAMP),
    ('PIPELINE_001', 'Feature Engineering', 'COMPLETED',
     (SELECT COUNT(*) FROM pipeline_features), 5.2, NULL, CURRENT_TIMESTAMP),
    ('PIPELINE_001', 'Train/Test Split', 'COMPLETED',
     (SELECT COUNT(*) FROM pipeline_train) + (SELECT COUNT(*) FROM pipeline_test), 2.1, NULL, CURRENT_TIMESTAMP),
    ('PIPELINE_001', 'Model Training', 'COMPLETED',
     (SELECT COUNT(*) FROM pipeline_predictions), 15.8, NULL, CURRENT_TIMESTAMP);

-- ============================================================================
-- STAGE 11: FINAL RESULTS EXPORT
-- ============================================================================

-- 11.1: Export pipeline results
SELECT
    'PIPELINE EXECUTION COMPLETE' as Status,
    (SELECT COUNT(*) FROM pipeline_raw_data) as RawDataRows,
    (SELECT COUNT(*) FROM pipeline_prepared_data) as PreparedDataRows,
    (SELECT COUNT(*) FROM pipeline_predictions) as PredictionsGenerated,
    (SELECT SQRT(AVG((actual - predicted) * (actual - predicted))) FROM pipeline_predictions WHERE predicted IS NOT NULL) as FinalRMSE,
    CURRENT_TIMESTAMP as CompletionTime;

-- 11.2: Export predictions for downstream use
SELECT
    time_index,
    ts as timestamp,
    actual,
    predicted,
    actual - predicted as error,
    ABS(actual - predicted) as absolute_error
FROM pipeline_predictions
ORDER BY time_index;

/*
UAF PIPELINE BEST PRACTICES:
□ Execute stages sequentially to ensure data dependencies
□ Use intermediate tables for debugging and validation
□ Log pipeline execution metadata for monitoring
□ Apply optimal parameters from parameter optimization
□ Validate data quality at each stage
□ Handle missing values before model training
□ Perform residual diagnostics after model fitting
□ Monitor performance metrics throughout pipeline
□ Document pipeline configuration and parameters
□ Test pipeline on subset before full execution

PIPELINE EXTENSIONS:
1. Add ensemble modeling (combine multiple UAF functions)
2. Implement automated retraining triggers
3. Add data drift detection
4. Include confidence intervals for predictions
5. Build model versioning and rollback capability
6. Add real-time streaming data ingestion
7. Implement A/B testing framework
8. Add automated alerting for anomalies

INTEGRATION POINTS:
- TD_DATA_PREPARATION → TD_PARAMETER_ESTIMATION
- TD_PARAMETER_ESTIMATION → TD_MODEL_SELECTION
- TD_MODEL_SELECTION → TD_CROSS_VALIDATION
- Model Predictions → TD_PORTMAN (residual diagnostics)
- All stages → Performance Monitoring

NEXT STEPS:
1. Customize pipeline for your specific use case
2. Apply optimized parameters from parameter_optimization.sql
3. Add domain-specific validation checks
4. Implement error handling and recovery
5. Set up scheduled pipeline execution
6. Monitor pipeline performance over time
*/
