-- =====================================================
-- TD_RegressionEvaluator - Evaluation Script
-- =====================================================
-- Purpose: Calculate regression metrics using TD_RegressionEvaluator
-- Function: TD_RegressionEvaluator
-- Metrics: RMSE, MAE, R², MAPE, MSE
-- =====================================================

-- =====================================================
-- Step 1: Execute TD_RegressionEvaluator
-- =====================================================

-- Calculate all regression metrics
DROP TABLE IF EXISTS {database}.regression_metrics;
CREATE MULTISET TABLE {database}.regression_metrics AS (
    SELECT * FROM TD_RegressionEvaluator (
        ON {database}.regression_evaluation_input AS InputTable
        USING
        ObservationColumn ('actual_value')
        PredictionColumn ('predicted_value')
        Metrics ('ALL')  -- Calculate all available metrics
    ) as dt
) WITH DATA;

-- Display results
SELECT * FROM {database}.regression_metrics;

-- =====================================================
-- Step 2: Parse and Display Individual Metrics
-- =====================================================

-- TD_RegressionEvaluator returns metrics in a specific format
-- Extract individual metrics for reporting
SELECT
    metric_name,
    CAST(metric_value AS DECIMAL(12,6)) as metric_value,
    CASE metric_name
        WHEN 'MSE' THEN 'Mean Squared Error - average of squared errors'
        WHEN 'RMSE' THEN 'Root Mean Squared Error - sqrt of MSE, same units as target'
        WHEN 'MAE' THEN 'Mean Absolute Error - average of absolute errors'
        WHEN 'MAPE' THEN 'Mean Absolute Percentage Error - percentage-based error'
        WHEN 'R2' THEN 'R-squared - proportion of variance explained (0-1)'
        ELSE 'Other metric'
    END as metric_description
FROM {database}.regression_metrics
ORDER BY
    CASE metric_name
        WHEN 'R2' THEN 1
        WHEN 'RMSE' THEN 2
        WHEN 'MAE' THEN 3
        WHEN 'MSE' THEN 4
        WHEN 'MAPE' THEN 5
        ELSE 6
    END;

-- =====================================================
-- Step 3: Metric Interpretation
-- =====================================================

-- Interpret R-squared value
SELECT
    metric_name,
    metric_value,
    CASE
        WHEN metric_name = 'R2' AND CAST(metric_value AS FLOAT) >= 0.9 THEN 'Excellent - Model explains 90%+ of variance'
        WHEN metric_name = 'R2' AND CAST(metric_value AS FLOAT) >= 0.7 THEN 'Good - Model explains 70-90% of variance'
        WHEN metric_name = 'R2' AND CAST(metric_value AS FLOAT) >= 0.5 THEN 'Moderate - Model explains 50-70% of variance'
        WHEN metric_name = 'R2' AND CAST(metric_value AS FLOAT) >= 0.3 THEN 'Weak - Model explains 30-50% of variance'
        WHEN metric_name = 'R2' AND CAST(metric_value AS FLOAT) < 0.3 THEN 'Poor - Model explains less than 30% of variance'
        ELSE 'N/A'
    END as interpretation
FROM {database}.regression_metrics
WHERE metric_name = 'R2';

-- =====================================================
-- Step 4: Compare with Manual Calculations
-- =====================================================

-- Verify TD_RegressionEvaluator results match manual calculations
WITH manual_metrics AS (
    SELECT
        'RMSE' as metric_name,
        CAST(SQRT(AVG(POWER(predicted_value - actual_value, 2))) AS DECIMAL(12,6)) as manual_value
    FROM {database}.regression_evaluation_input

    UNION ALL

    SELECT
        'MAE' as metric_name,
        CAST(AVG(ABS(predicted_value - actual_value)) AS DECIMAL(12,6)) as manual_value
    FROM {database}.regression_evaluation_input

    UNION ALL

    SELECT
        'MSE' as metric_name,
        CAST(AVG(POWER(predicted_value - actual_value, 2)) AS DECIMAL(12,6)) as manual_value
    FROM {database}.regression_evaluation_input

    UNION ALL

    SELECT
        'R2' as metric_name,
        CAST(1 - (SUM(POWER(predicted_value - actual_value, 2)) /
             NULLIF(SUM(POWER(actual_value - AVG(actual_value) OVER(), 2)), 0)) AS DECIMAL(12,6)) as manual_value
    FROM {database}.regression_evaluation_input
),
td_metrics AS (
    SELECT
        metric_name,
        CAST(metric_value AS DECIMAL(12,6)) as td_value
    FROM {database}.regression_metrics
    WHERE metric_name IN ('RMSE', 'MAE', 'MSE', 'R2')
)
SELECT
    m.metric_name,
    m.manual_value,
    t.td_value,
    CAST(ABS(m.manual_value - t.td_value) AS DECIMAL(12,8)) as difference,
    CASE
        WHEN ABS(m.manual_value - t.td_value) < 0.0001 THEN 'Verified'
        ELSE 'Check Calculation'
    END as verification_status
FROM manual_metrics m
INNER JOIN td_metrics t ON m.metric_name = t.metric_name
ORDER BY m.metric_name;

-- =====================================================
-- Step 5: Model Performance Summary
-- =====================================================

-- Create comprehensive performance report
SELECT
    'Regression Model Performance Summary' as report_title,
    (SELECT COUNT(*) FROM {database}.regression_evaluation_input) as n_observations,
    (SELECT CAST(metric_value AS DECIMAL(10,6)) FROM {database}.regression_metrics WHERE metric_name = 'R2') as r_squared,
    (SELECT CAST(metric_value AS DECIMAL(12,6)) FROM {database}.regression_metrics WHERE metric_name = 'RMSE') as rmse,
    (SELECT CAST(metric_value AS DECIMAL(12,6)) FROM {database}.regression_metrics WHERE metric_name = 'MAE') as mae,
    (SELECT CAST(metric_value AS DECIMAL(12,6)) FROM {database}.regression_metrics WHERE metric_name = 'MSE') as mse,
    CASE
        WHEN (SELECT CAST(metric_value AS FLOAT) FROM {database}.regression_metrics WHERE metric_name = 'R2') >= 0.9 THEN 'Excellent'
        WHEN (SELECT CAST(metric_value AS FLOAT) FROM {database}.regression_metrics WHERE metric_name = 'R2') >= 0.7 THEN 'Good'
        WHEN (SELECT CAST(metric_value AS FLOAT) FROM {database}.regression_metrics WHERE metric_name = 'R2') >= 0.5 THEN 'Moderate'
        ELSE 'Needs Improvement'
    END as overall_assessment;

-- =====================================================
-- Step 6: Metric-Specific Queries
-- =====================================================

-- Option 1: Request specific metrics only
/*
DROP TABLE IF EXISTS {database}.regression_metrics_rmse;
CREATE MULTISET TABLE {database}.regression_metrics_rmse AS (
    SELECT * FROM TD_RegressionEvaluator (
        ON {database}.regression_evaluation_input AS InputTable
        USING
        ObservationColumn ('actual_value')
        PredictionColumn ('predicted_value')
        Metrics ('RMSE')  -- Only RMSE
    ) as dt
) WITH DATA;

SELECT * FROM {database}.regression_metrics_rmse;
*/

-- Option 2: Request multiple specific metrics
/*
DROP TABLE IF EXISTS {database}.regression_metrics_subset;
CREATE MULTISET TABLE {database}.regression_metrics_subset AS (
    SELECT * FROM TD_RegressionEvaluator (
        ON {database}.regression_evaluation_input AS InputTable
        USING
        ObservationColumn ('actual_value')
        PredictionColumn ('predicted_value')
        Metrics ('RMSE', 'MAE', 'R2')  -- Selected metrics
    ) as dt
) WITH DATA;

SELECT * FROM {database}.regression_metrics_subset;
*/

-- =====================================================
-- Step 7: Store Results for Comparison
-- =====================================================

-- Create evaluation history table for tracking model performance over time
DROP TABLE IF EXISTS {database}.evaluation_history;
CREATE TABLE {database}.evaluation_history (
    eval_id INTEGER,
    eval_date TIMESTAMP,
    model_name VARCHAR(100),
    n_observations INTEGER,
    r_squared DECIMAL(10,6),
    rmse DECIMAL(12,6),
    mae DECIMAL(12,6),
    mse DECIMAL(12,6),
    notes VARCHAR(500)
);

-- Insert current evaluation results
INSERT INTO {database}.evaluation_history
SELECT
    1 as eval_id,
    CURRENT_TIMESTAMP as eval_date,
    '{model_name}' as model_name,
    (SELECT COUNT(*) FROM {database}.regression_evaluation_input) as n_observations,
    (SELECT CAST(metric_value AS DECIMAL(10,6)) FROM {database}.regression_metrics WHERE metric_name = 'R2') as r_squared,
    (SELECT CAST(metric_value AS DECIMAL(12,6)) FROM {database}.regression_metrics WHERE metric_name = 'RMSE') as rmse,
    (SELECT CAST(metric_value AS DECIMAL(12,6)) FROM {database}.regression_metrics WHERE metric_name = 'MAE') as mae,
    (SELECT CAST(metric_value AS DECIMAL(12,6)) FROM {database}.regression_metrics WHERE metric_name = 'MSE') as mse,
    'Initial evaluation' as notes;

-- View evaluation history
SELECT * FROM {database}.evaluation_history ORDER BY eval_date DESC;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- Replace placeholders:
--   {database} - Your database name
--   {model_name} - Name/description of model being evaluated
--
-- TD_RegressionEvaluator parameters:
--   ObservationColumn: Column with actual/ground truth values (required)
--   PredictionColumn: Column with predicted values (required)
--   Metrics: List of metrics to calculate (default: 'ALL')
--     Options: 'RMSE', 'MAE', 'R2', 'MSE', 'MAPE', 'ALL'
--
-- Metric interpretation:
--   R² (0-1): Proportion of variance explained (higher is better)
--   RMSE: Root mean squared error (lower is better, same units as target)
--   MAE: Mean absolute error (lower is better, same units as target)
--   MSE: Mean squared error (lower is better, squared units)
--   MAPE: Mean absolute percentage error (lower is better, percentage)
--
-- Next steps:
--   1. Run diagnostic_queries.sql for detailed error analysis
--   2. Run parameter_tuning.sql to compare multiple models
--   3. Investigate prediction errors using residual analysis
-- =====================================================
