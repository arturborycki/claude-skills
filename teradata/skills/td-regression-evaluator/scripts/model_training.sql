-- =====================================================
-- TD_RegressionEvaluator - Model Training Script
-- =====================================================
-- Purpose: TD_RegressionEvaluator is for EVALUATION ONLY
-- Function: TD_RegressionEvaluator
-- Note: NO MODEL TRAINING occurs with this function
-- =====================================================

-- IMPORTANT: TD_RegressionEvaluator does NOT train models
-- It evaluates predictions from already-trained regression models
-- This script demonstrates proper data preparation

-- =====================================================
-- Understanding TD_RegressionEvaluator
-- =====================================================

-- TD_RegressionEvaluator is used to:
-- 1. Calculate regression metrics (RMSE, MAE, R², MAPE, MSE)
-- 2. Assess model performance on test data
-- 3. Compare multiple models

-- TD_RegressionEvaluator is NOT used to:
-- 1. Train regression models
-- 2. Generate predictions
-- 3. Fit model parameters

-- =====================================================
-- Input Requirements
-- =====================================================

-- TD_RegressionEvaluator requires a single table with:
-- - Actual values (ground truth)
-- - Predicted values (from your trained model)
-- - Optional: ID column for tracking

-- Example structure:
/*
CREATE TABLE evaluation_data (
    id INTEGER,
    actual_value FLOAT,
    predicted_value FLOAT
);
*/

-- =====================================================
-- Verify Prepared Data
-- =====================================================

-- Check that preprocessing.sql has been run
SELECT
    'Data Preparation Check' as check_type,
    COUNT(*) as total_records,
    COUNT(actual_value) as actual_count,
    COUNT(predicted_value) as predicted_count,
    CASE
        WHEN COUNT(*) > 0 AND COUNT(actual_value) = COUNT(*) AND COUNT(predicted_value) = COUNT(*)
        THEN 'READY FOR EVALUATION'
        ELSE 'RUN PREPROCESSING FIRST'
    END as status
FROM {database}.regression_evaluation_input;

-- =====================================================
-- Where Do Predictions Come From?
-- =====================================================

-- Predictions should come from a trained regression model such as:
-- 1. TD_LinearRegression / TD_GLM
-- 2. TD_DecisionForest / TD_RandomForest
-- 3. TD_SVM (regression mode)
-- 4. TD_NeuralNet (regression)
-- 5. External models (Python, R, etc.)

-- Example workflow for getting predictions:
/*
-- Step 1: Train a model (e.g., Linear Regression)
DROP TABLE IF EXISTS {database}.linear_model;
CREATE MULTISET TABLE {database}.linear_model AS (
    SELECT * FROM TD_LinearRegression(
        ON {database}.training_data AS InputTable
        USING
        TargetColumn('{target}')
        InputColumns('{feature1}', '{feature2}', '{feature3}')
    ) as dt
) WITH DATA;

-- Step 2: Generate predictions on test data
DROP TABLE IF EXISTS {database}.predictions;
CREATE MULTISET TABLE {database}.predictions AS (
    SELECT * FROM TD_GLMPredict(
        ON {database}.test_data AS InputTable
        ON {database}.linear_model AS ModelTable
        USING
        IDColumn('{id_column}')
        Accumulate('{id_column}', '{actual_column}')
    ) as dt
) WITH DATA;

-- Step 3: Now use TD_RegressionEvaluator (in evaluation.sql)
*/

-- =====================================================
-- Correlation Analysis (Pre-Evaluation Check)
-- =====================================================

-- Check correlation between actual and predicted values
-- High correlation (>0.7) suggests good model performance
SELECT
    CAST(CORR(actual_value, predicted_value) AS DECIMAL(10,6)) as pearson_correlation,
    CAST(COVAR_POP(actual_value, predicted_value) AS DECIMAL(12,6)) as covariance,
    CASE
        WHEN CORR(actual_value, predicted_value) > 0.9 THEN 'Excellent (>0.9)'
        WHEN CORR(actual_value, predicted_value) > 0.7 THEN 'Good (0.7-0.9)'
        WHEN CORR(actual_value, predicted_value) > 0.5 THEN 'Moderate (0.5-0.7)'
        WHEN CORR(actual_value, predicted_value) > 0.3 THEN 'Weak (0.3-0.5)'
        ELSE 'Very Weak (<0.3)'
    END as correlation_strength
FROM {database}.regression_evaluation_input;

-- =====================================================
-- Manual Metric Calculation (Verification)
-- =====================================================

-- Calculate regression metrics manually before using TD_RegressionEvaluator
-- This helps verify the function output
SELECT
    'Manual Metric Calculation' as metric_source,
    COUNT(*) as n_observations,

    -- Mean Squared Error (MSE)
    CAST(AVG(POWER(predicted_value - actual_value, 2)) AS DECIMAL(12,6)) as mse,

    -- Root Mean Squared Error (RMSE)
    CAST(SQRT(AVG(POWER(predicted_value - actual_value, 2))) AS DECIMAL(12,6)) as rmse,

    -- Mean Absolute Error (MAE)
    CAST(AVG(ABS(predicted_value - actual_value)) AS DECIMAL(12,6)) as mae,

    -- Mean Absolute Percentage Error (MAPE)
    CAST(AVG(ABS((predicted_value - actual_value) / NULLIF(actual_value, 0)) * 100) AS DECIMAL(12,6)) as mape,

    -- R-squared (Coefficient of Determination)
    CAST(1 - (SUM(POWER(predicted_value - actual_value, 2)) /
         NULLIF(SUM(POWER(actual_value - AVG(actual_value) OVER(), 2)), 0)) AS DECIMAL(10,6)) as r_squared,

    -- Adjusted R-squared (if you have p features and n observations)
    -- CAST(1 - ((1 - r_squared) * (n - 1) / (n - p - 1)) AS DECIMAL(10,6)) as adj_r_squared

    CASE
        WHEN 1 - (SUM(POWER(predicted_value - actual_value, 2)) /
             NULLIF(SUM(POWER(actual_value - AVG(actual_value) OVER(), 2)), 0)) > 0.9 THEN 'Excellent'
        WHEN 1 - (SUM(POWER(predicted_value - actual_value, 2)) /
             NULLIF(SUM(POWER(actual_value - AVG(actual_value) OVER(), 2)), 0)) > 0.7 THEN 'Good'
        WHEN 1 - (SUM(POWER(predicted_value - actual_value, 2)) /
             NULLIF(SUM(POWER(actual_value - AVG(actual_value) OVER(), 2)), 0)) > 0.5 THEN 'Moderate'
        ELSE 'Poor'
    END as model_quality
FROM {database}.regression_evaluation_input;

-- =====================================================
-- Baseline Model Comparison
-- =====================================================

-- Compare your model against simple baselines
-- Baseline 1: Always predict the mean
-- Baseline 2: Always predict the median

WITH baseline_mean AS (
    SELECT AVG(actual_value) as mean_prediction
    FROM {database}.regression_evaluation_input
),
baseline_median AS (
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY actual_value) as median_prediction
    FROM {database}.regression_evaluation_input
),
model_metrics AS (
    SELECT
        SQRT(AVG(POWER(predicted_value - actual_value, 2))) as model_rmse,
        AVG(ABS(predicted_value - actual_value)) as model_mae
    FROM {database}.regression_evaluation_input
),
mean_baseline_metrics AS (
    SELECT
        SQRT(AVG(POWER(mean_prediction - actual_value, 2))) as baseline_mean_rmse,
        AVG(ABS(mean_prediction - actual_value)) as baseline_mean_mae
    FROM {database}.regression_evaluation_input, baseline_mean
),
median_baseline_metrics AS (
    SELECT
        SQRT(AVG(POWER(median_prediction - actual_value, 2))) as baseline_median_rmse,
        AVG(ABS(median_prediction - actual_value)) as baseline_median_mae
    FROM {database}.regression_evaluation_input, baseline_median
)
SELECT
    'Model vs Baselines' as comparison_type,
    CAST(model_rmse AS DECIMAL(12,6)) as model_rmse,
    CAST(baseline_mean_rmse AS DECIMAL(12,6)) as mean_baseline_rmse,
    CAST(baseline_median_rmse AS DECIMAL(12,6)) as median_baseline_rmse,
    CASE
        WHEN model_rmse < baseline_mean_rmse AND model_rmse < baseline_median_rmse
        THEN 'Model outperforms both baselines'
        WHEN model_rmse < baseline_mean_rmse
        THEN 'Model outperforms mean baseline'
        ELSE 'Model does not beat baselines - investigate'
    END as performance_assessment
FROM model_metrics, mean_baseline_metrics, median_baseline_metrics;

-- =====================================================
-- Data Ready for TD_RegressionEvaluator
-- =====================================================

-- Confirm everything is set up correctly
SELECT
    'Pre-Evaluation Summary' as summary_type,
    (SELECT COUNT(*) FROM {database}.regression_evaluation_input) as total_records,
    (SELECT COUNT(*) FROM {database}.regression_evaluation_input WHERE actual_value IS NULL) as null_actuals,
    (SELECT COUNT(*) FROM {database}.regression_evaluation_input WHERE predicted_value IS NULL) as null_predictions,
    CASE
        WHEN (SELECT COUNT(*) FROM {database}.regression_evaluation_input) >= 30
         AND (SELECT COUNT(*) FROM {database}.regression_evaluation_input WHERE actual_value IS NULL) = 0
         AND (SELECT COUNT(*) FROM {database}.regression_evaluation_input WHERE predicted_value IS NULL) = 0
        THEN 'READY - Proceed to evaluation.sql'
        ELSE 'NOT READY - Review preprocessing'
    END as status;

-- =====================================================
-- Next Steps
-- =====================================================

-- Now run evaluation.sql to execute TD_RegressionEvaluator
-- The function will calculate all regression metrics automatically

-- =====================================================
-- Usage Notes:
-- =====================================================
-- Replace placeholders:
--   {database} - Your database name
--
-- Remember:
--   1. TD_RegressionEvaluator does NOT train models
--   2. You must provide actual AND predicted values
--   3. Use trained models (TD_LinearRegression, TD_GLM, etc.) to generate predictions
--   4. Always compare against baseline models
--   5. Minimum 30 observations recommended for reliable metrics
--
-- Common training functions for regression:
--   - TD_LinearRegression / TD_GLM
--   - TD_DecisionForest
--   - TD_RandomForest
--   - TD_SVM (SVMSparsePredict_MLE)
--   - TD_XGBoost
--
-- Next: Run evaluation.sql to calculate metrics with TD_RegressionEvaluator
-- =====================================================
