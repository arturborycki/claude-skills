-- =====================================================
-- TD_RegressionEvaluator - Diagnostic Queries
-- =====================================================
-- Purpose: Deep dive into regression model performance
-- Focus: Residual analysis, error patterns, outliers
-- =====================================================

-- =====================================================
-- Query 1: View All Metrics from TD_RegressionEvaluator
-- =====================================================

SELECT 
    metric_name,
    CAST(metric_value AS DECIMAL(12,6)) as metric_value
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
-- Query 2: Residual Analysis
-- =====================================================

WITH residuals AS (
    SELECT
        {id_column},
        actual_value,
        predicted_value,
        (predicted_value - actual_value) as residual,
        ABS(predicted_value - actual_value) as abs_residual,
        POWER(predicted_value - actual_value, 2) as squared_residual,
        (predicted_value - actual_value) / STDDEV(predicted_value - actual_value) OVER() as standardized_residual
    FROM {database}.regression_evaluation_input
)
SELECT
    'Residual Statistics' as analysis_type,
    COUNT(*) as n_observations,
    CAST(AVG(residual) AS DECIMAL(12,6)) as mean_residual,
    CAST(STDDEV(residual) AS DECIMAL(12,6)) as std_residual,
    CAST(MIN(residual) AS DECIMAL(12,6)) as min_residual,
    CAST(MAX(residual) AS DECIMAL(12,6)) as max_residual,
    CAST(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY residual) AS DECIMAL(12,6)) as q1_residual,
    CAST(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY residual) AS DECIMAL(12,6)) as median_residual,
    CAST(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY residual) AS DECIMAL(12,6)) as q3_residual
FROM residuals;

-- =====================================================
-- Query 3: Residual Distribution (Histogram Bins)
-- =====================================================

SELECT
    CASE
        WHEN standardized_residual < -3 THEN '< -3 SD'
        WHEN standardized_residual < -2 THEN '-3 to -2 SD'
        WHEN standardized_residual < -1 THEN '-2 to -1 SD'
        WHEN standardized_residual < 0 THEN '-1 to 0 SD'
        WHEN standardized_residual < 1 THEN '0 to 1 SD'
        WHEN standardized_residual < 2 THEN '1 to 2 SD'
        WHEN standardized_residual < 3 THEN '2 to 3 SD'
        ELSE '> 3 SD'
    END as residual_bin,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    RPAD('*', CAST(COUNT(*) * 50.0 / MAX(COUNT(*)) OVER() AS INTEGER), '*') as distribution_chart
FROM (
    SELECT
        (predicted_value - actual_value) / STDDEV(predicted_value - actual_value) OVER() as standardized_residual
    FROM {database}.regression_evaluation_input
) residuals
GROUP BY 1
ORDER BY 1;

-- =====================================================
-- Query 4: Error Analysis by Prediction Magnitude
-- =====================================================

WITH quartiles AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY predicted_value) as q1,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY predicted_value) as q2,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY predicted_value) as q3
    FROM {database}.regression_evaluation_input
)
SELECT
    CASE
        WHEN predicted_value <= q1 THEN 'Q1 (Lowest 25%)'
        WHEN predicted_value <= q2 THEN 'Q2 (25-50%)'
        WHEN predicted_value <= q3 THEN 'Q3 (50-75%)'
        ELSE 'Q4 (Top 25%)'
    END as prediction_quartile,
    COUNT(*) as n_observations,
    CAST(AVG(actual_value) AS DECIMAL(12,4)) as avg_actual,
    CAST(AVG(predicted_value) AS DECIMAL(12,4)) as avg_predicted,
    CAST(SQRT(AVG(POWER(predicted_value - actual_value, 2))) AS DECIMAL(12,6)) as rmse,
    CAST(AVG(ABS(predicted_value - actual_value)) AS DECIMAL(12,6)) as mae,
    CAST(AVG((predicted_value - actual_value) / actual_value * 100) AS DECIMAL(8,2)) as mean_percentage_error
FROM {database}.regression_evaluation_input, quartiles
GROUP BY 1
ORDER BY 1;

-- =====================================================
-- Query 5: Identify Worst Predictions (Largest Errors)
-- =====================================================

SELECT TOP 20
    {id_column},
    CAST(actual_value AS DECIMAL(12,4)) as actual,
    CAST(predicted_value AS DECIMAL(12,4)) as predicted,
    CAST(predicted_value - actual_value AS DECIMAL(12,4)) as error,
    CAST(ABS(predicted_value - actual_value) AS DECIMAL(12,4)) as absolute_error,
    CAST(ABS((predicted_value - actual_value) / NULLIF(actual_value, 0) * 100) AS DECIMAL(8,2)) as percentage_error,
    CASE
        WHEN predicted_value > actual_value THEN 'Over-prediction'
        ELSE 'Under-prediction'
    END as error_direction
FROM {database}.regression_evaluation_input
ORDER BY absolute_error DESC;

-- =====================================================
-- Query 6: Over-prediction vs Under-prediction Analysis
-- =====================================================

SELECT
    CASE
        WHEN predicted_value > actual_value THEN 'Over-predictions'
        WHEN predicted_value < actual_value THEN 'Under-predictions'
        ELSE 'Exact predictions'
    END as prediction_bias,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    CAST(AVG(ABS(predicted_value - actual_value)) AS DECIMAL(12,6)) as avg_absolute_error,
    CAST(AVG(predicted_value - actual_value) AS DECIMAL(12,6)) as avg_signed_error
FROM {database}.regression_evaluation_input
GROUP BY 1
ORDER BY 1;

-- =====================================================
-- Query 7: Heteroscedasticity Check
-- =====================================================

-- Check if error variance increases with predicted values
WITH binned_predictions AS (
    SELECT
        NTILE(10) OVER (ORDER BY predicted_value) as decile,
        predicted_value,
        actual_value,
        POWER(predicted_value - actual_value, 2) as squared_error
    FROM {database}.regression_evaluation_input
)
SELECT
    decile,
    COUNT(*) as n_observations,
    CAST(AVG(predicted_value) AS DECIMAL(12,4)) as avg_predicted,
    CAST(STDDEV(predicted_value - actual_value) AS DECIMAL(12,6)) as std_residual,
    CAST(AVG(squared_error) AS DECIMAL(12,6)) as avg_squared_error,
    CASE
        WHEN decile = 1 THEN 'Baseline'
        WHEN STDDEV(predicted_value - actual_value) > 
             (SELECT STDDEV(predicted_value - actual_value) * 1.5 
              FROM binned_predictions WHERE decile = 1)
        THEN 'Higher variance'
        ELSE 'Similar variance'
    END as variance_assessment
FROM binned_predictions
GROUP BY 1
ORDER BY 1;

-- =====================================================
-- Query 8: Prediction Accuracy by Actual Value Range
-- =====================================================

SELECT
    CASE
        WHEN actual_value <= PERCENTILE_CONT(0.2) WITHIN GROUP (ORDER BY actual_value) OVER() 
            THEN '1. Lowest 20%'
        WHEN actual_value <= PERCENTILE_CONT(0.4) WITHIN GROUP (ORDER BY actual_value) OVER() 
            THEN '2. Low 20-40%'
        WHEN actual_value <= PERCENTILE_CONT(0.6) WITHIN GROUP (ORDER BY actual_value) OVER() 
            THEN '3. Middle 40-60%'
        WHEN actual_value <= PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY actual_value) OVER() 
            THEN '4. High 60-80%'
        ELSE '5. Highest 20%'
    END as actual_value_quintile,
    COUNT(*) as n_observations,
    CAST(AVG(actual_value) AS DECIMAL(12,4)) as avg_actual,
    CAST(AVG(predicted_value) AS DECIMAL(12,4)) as avg_predicted,
    CAST(CORR(actual_value, predicted_value) AS DECIMAL(10,6)) as correlation,
    CAST(SQRT(AVG(POWER(predicted_value - actual_value, 2))) AS DECIMAL(12,6)) as rmse,
    CAST(AVG(ABS(predicted_value - actual_value)) AS DECIMAL(12,6)) as mae
FROM {database}.regression_evaluation_input
GROUP BY 1
ORDER BY 1;

-- =====================================================
-- Query 9: Comprehensive Diagnostics Summary
-- =====================================================

WITH metrics AS (
    SELECT
        COUNT(*) as n_obs,
        SQRT(AVG(POWER(predicted_value - actual_value, 2))) as rmse,
        AVG(ABS(predicted_value - actual_value)) as mae,
        1 - (SUM(POWER(predicted_value - actual_value, 2)) /
             NULLIF(SUM(POWER(actual_value - AVG(actual_value) OVER(), 2)), 0)) as r_squared,
        CORR(actual_value, predicted_value) as correlation,
        AVG(predicted_value - actual_value) as mean_error
    FROM {database}.regression_evaluation_input
)
SELECT
    'Regression Diagnostics Summary' as report_type,
    n_obs as observations,
    CAST(rmse AS DECIMAL(12,6)) as rmse,
    CAST(mae AS DECIMAL(12,6)) as mae,
    CAST(r_squared AS DECIMAL(10,6)) as r_squared,
    CAST(correlation AS DECIMAL(10,6)) as correlation,
    CAST(mean_error AS DECIMAL(12,6)) as mean_bias,
    CASE
        WHEN r_squared > 0.9 THEN 'Excellent (R²>0.9)'
        WHEN r_squared > 0.7 THEN 'Good (R²>0.7)'
        WHEN r_squared > 0.5 THEN 'Moderate (R²>0.5)'
        WHEN r_squared > 0.3 THEN 'Weak (R²>0.3)'
        ELSE 'Poor (R²<=0.3)'
    END as model_quality,
    CASE
        WHEN ABS(mean_error) / mae < 0.1 THEN 'Unbiased'
        WHEN mean_error > 0 THEN 'Positive bias (over-prediction)'
        ELSE 'Negative bias (under-prediction)'
    END as bias_assessment
FROM metrics;

-- =====================================================
-- Query 10: Outlier Residuals (Potential Data Issues)
-- =====================================================

WITH residuals AS (
    SELECT
        {id_column},
        actual_value,
        predicted_value,
        (predicted_value - actual_value) as residual,
        (predicted_value - actual_value) / STDDEV(predicted_value - actual_value) OVER() as standardized_residual
    FROM {database}.regression_evaluation_input
)
SELECT
    {id_column},
    CAST(actual_value AS DECIMAL(12,4)) as actual,
    CAST(predicted_value AS DECIMAL(12,4)) as predicted,
    CAST(residual AS DECIMAL(12,4)) as residual,
    CAST(standardized_residual AS DECIMAL(10,4)) as std_residual,
    CASE
        WHEN ABS(standardized_residual) > 3 THEN 'Extreme outlier (>3σ)'
        WHEN ABS(standardized_residual) > 2 THEN 'Moderate outlier (>2σ)'
        ELSE 'Normal'
    END as outlier_status
FROM residuals
WHERE ABS(standardized_residual) > 2
ORDER BY ABS(standardized_residual) DESC;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- Replace placeholders:
--   {database} - Your database name
--   {id_column} - Unique identifier column
--
-- Key diagnostic insights:
--   1. Residual distribution should be approximately normal
--   2. Mean residual should be close to zero (unbiased)
--   3. Residual variance should be constant (homoscedastic)
--   4. No systematic patterns in residuals
--   5. Few extreme outliers (|standardized residual| > 3)
--
-- Red flags:
--   - Mean residual far from zero: Model is biased
--   - Increasing residual variance: Heteroscedasticity
--   - Many outliers: Data quality issues or model misspecification
--   - Different performance across ranges: Model not generalizing
-- =====================================================
