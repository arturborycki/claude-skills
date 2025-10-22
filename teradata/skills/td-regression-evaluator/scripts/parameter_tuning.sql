-- =====================================================
-- TD_RegressionEvaluator - Parameter Tuning/Model Comparison
-- =====================================================
-- Purpose: Compare multiple regression models
-- Note: TD_RegressionEvaluator has no tunable parameters
-- Use this script to compare different models
-- =====================================================

-- TD_RegressionEvaluator does NOT have tunable parameters
-- Instead, use this script to compare multiple models

-- =====================================================
-- Scenario 1: Compare Multiple Models Side-by-Side
-- =====================================================

-- Assume you have predictions from 3 different models:
-- Model 1: Linear Regression
-- Model 2: Random Forest
-- Model 3: Gradient Boosting

SELECT
    'Linear Regression' as model_name,
    CAST(SQRT(AVG(POWER({predicted_col_model1} - {actual_column}, 2))) AS DECIMAL(12,6)) as rmse,
    CAST(AVG(ABS({predicted_col_model1} - {actual_column})) AS DECIMAL(12,6)) as mae,
    CAST(1 - (SUM(POWER({predicted_col_model1} - {actual_column}, 2)) /
         NULLIF(SUM(POWER({actual_column} - AVG({actual_column}) OVER(), 2)), 0)) AS DECIMAL(10,6)) as r_squared
FROM {database}.{multi_model_predictions_table}

UNION ALL

SELECT
    'Random Forest' as model_name,
    CAST(SQRT(AVG(POWER({predicted_col_model2} - {actual_column}, 2))) AS DECIMAL(12,6)) as rmse,
    CAST(AVG(ABS({predicted_col_model2} - {actual_column})) AS DECIMAL(12,6)) as mae,
    CAST(1 - (SUM(POWER({predicted_col_model2} - {actual_column}, 2)) /
         NULLIF(SUM(POWER({actual_column} - AVG({actual_column}) OVER(), 2)), 0)) AS DECIMAL(10,6)) as r_squared
FROM {database}.{multi_model_predictions_table}

UNION ALL

SELECT
    'Gradient Boosting' as model_name,
    CAST(SQRT(AVG(POWER({predicted_col_model3} - {actual_column}, 2))) AS DECIMAL(12,6)) as rmse,
    CAST(AVG(ABS({predicted_col_model3} - {actual_column})) AS DECIMAL(12,6)) as mae,
    CAST(1 - (SUM(POWER({predicted_col_model3} - {actual_column}, 2)) /
         NULLIF(SUM(POWER({actual_column} - AVG({actual_column}) OVER(), 2)), 0)) AS DECIMAL(10,6)) as r_squared
FROM {database}.{multi_model_predictions_table}

ORDER BY r_squared DESC;

-- =====================================================
-- Scenario 2: Rank Models by Different Metrics
-- =====================================================

WITH model_metrics AS (
    SELECT 'Linear Regression' as model_name,
           SQRT(AVG(POWER({predicted_col_model1} - {actual_column}, 2))) as rmse,
           AVG(ABS({predicted_col_model1} - {actual_column})) as mae,
           1 - (SUM(POWER({predicted_col_model1} - {actual_column}, 2)) /
                NULLIF(SUM(POWER({actual_column} - AVG({actual_column}) OVER(), 2)), 0)) as r_squared
    FROM {database}.{multi_model_predictions_table}
    
    UNION ALL
    
    SELECT 'Random Forest' as model_name,
           SQRT(AVG(POWER({predicted_col_model2} - {actual_column}, 2))) as rmse,
           AVG(ABS({predicted_col_model2} - {actual_column})) as mae,
           1 - (SUM(POWER({predicted_col_model2} - {actual_column}, 2)) /
                NULLIF(SUM(POWER({actual_column} - AVG({actual_column}) OVER(), 2)), 0)) as r_squared
    FROM {database}.{multi_model_predictions_table}
    
    UNION ALL
    
    SELECT 'Gradient Boosting' as model_name,
           SQRT(AVG(POWER({predicted_col_model3} - {actual_column}, 2))) as rmse,
           AVG(ABS({predicted_col_model3} - {actual_column})) as mae,
           1 - (SUM(POWER({predicted_col_model3} - {actual_column}, 2)) /
                NULLIF(SUM(POWER({actual_column} - AVG({actual_column}) OVER(), 2)), 0)) as r_squared
    FROM {database}.{multi_model_predictions_table}
)
SELECT
    model_name,
    CAST(rmse AS DECIMAL(12,6)) as rmse,
    CAST(mae AS DECIMAL(12,6)) as mae,
    CAST(r_squared AS DECIMAL(10,6)) as r_squared,
    RANK() OVER (ORDER BY rmse ASC) as rmse_rank,
    RANK() OVER (ORDER BY mae ASC) as mae_rank,
    RANK() OVER (ORDER BY r_squared DESC) as r_squared_rank,
    (RANK() OVER (ORDER BY rmse ASC) + 
     RANK() OVER (ORDER BY mae ASC) + 
     RANK() OVER (ORDER BY r_squared DESC)) as combined_rank
FROM model_metrics
ORDER BY combined_rank ASC;

-- =====================================================
-- Scenario 3: Statistical Significance Testing
-- =====================================================

-- Test if Model 1 is significantly better than Model 2
WITH residuals AS (
    SELECT
        {id_column},
        POWER({predicted_col_model1} - {actual_column}, 2) as mse_model1,
        POWER({predicted_col_model2} - {actual_column}, 2) as mse_model2,
        POWER({predicted_col_model1} - {actual_column}, 2) - 
        POWER({predicted_col_model2} - {actual_column}, 2) as mse_difference
    FROM {database}.{multi_model_predictions_table}
)
SELECT
    'Statistical Comparison: Model 1 vs Model 2' as test_name,
    CAST(AVG(mse_model1) AS DECIMAL(12,6)) as model1_avg_mse,
    CAST(AVG(mse_model2) AS DECIMAL(12,6)) as model2_avg_mse,
    CAST(AVG(mse_difference) AS DECIMAL(12,6)) as avg_mse_difference,
    CAST(STDDEV(mse_difference) AS DECIMAL(12,6)) as std_mse_difference,
    CAST(AVG(mse_difference) / NULLIF(STDDEV(mse_difference) / SQRT(COUNT(*)), 0) AS DECIMAL(10,4)) as t_statistic,
    COUNT(*) as n_samples,
    CASE
        WHEN ABS(AVG(mse_difference) / NULLIF(STDDEV(mse_difference) / SQRT(COUNT(*)), 0)) > 2.576 
            THEN 'Significantly different (p<0.01)'
        WHEN ABS(AVG(mse_difference) / NULLIF(STDDEV(mse_difference) / SQRT(COUNT(*)), 0)) > 1.96 
            THEN 'Significantly different (p<0.05)'
        ELSE 'No significant difference (p>=0.05)'
    END as significance_interpretation
FROM residuals;

-- =====================================================
-- Scenario 4: Model Performance by Data Segment
-- =====================================================

-- Compare model performance across different value ranges
SELECT
    CASE
        WHEN {actual_column} <= PERCENTILE_CONT(0.33) WITHIN GROUP (ORDER BY {actual_column}) OVER() 
            THEN 'Low Range (Bottom 33%)'
        WHEN {actual_column} <= PERCENTILE_CONT(0.67) WITHIN GROUP (ORDER BY {actual_column}) OVER() 
            THEN 'Mid Range (33-67%)'
        ELSE 'High Range (Top 33%)'
    END as value_segment,
    COUNT(*) as n_observations,
    -- Model 1 metrics
    CAST(SQRT(AVG(POWER({predicted_col_model1} - {actual_column}, 2))) AS DECIMAL(12,6)) as model1_rmse,
    CAST(AVG(ABS({predicted_col_model1} - {actual_column})) AS DECIMAL(12,6)) as model1_mae,
    -- Model 2 metrics
    CAST(SQRT(AVG(POWER({predicted_col_model2} - {actual_column}, 2))) AS DECIMAL(12,6)) as model2_rmse,
    CAST(AVG(ABS({predicted_col_model2} - {actual_column})) AS DECIMAL(12,6)) as model2_mae,
    -- Best model per segment
    CASE
        WHEN SQRT(AVG(POWER({predicted_col_model1} - {actual_column}, 2))) < 
             SQRT(AVG(POWER({predicted_col_model2} - {actual_column}, 2)))
        THEN 'Model 1'
        ELSE 'Model 2'
    END as best_model
FROM {database}.{multi_model_predictions_table}
GROUP BY 1
ORDER BY 1;

-- =====================================================
-- Scenario 5: Ensemble Model Comparison
-- =====================================================

-- Create simple ensemble (average of predictions) and compare
WITH ensemble AS (
    SELECT
        {id_column},
        {actual_column},
        ({predicted_col_model1} + {predicted_col_model2} + {predicted_col_model3}) / 3.0 as ensemble_prediction,
        {predicted_col_model1},
        {predicted_col_model2},
        {predicted_col_model3}
    FROM {database}.{multi_model_predictions_table}
)
SELECT
    'Individual vs Ensemble' as comparison_type,
    CAST(SQRT(AVG(POWER({predicted_col_model1} - {actual_column}, 2))) AS DECIMAL(12,6)) as model1_rmse,
    CAST(SQRT(AVG(POWER({predicted_col_model2} - {actual_column}, 2))) AS DECIMAL(12,6)) as model2_rmse,
    CAST(SQRT(AVG(POWER({predicted_col_model3} - {actual_column}, 2))) AS DECIMAL(12,6)) as model3_rmse,
    CAST(SQRT(AVG(POWER(ensemble_prediction - {actual_column}, 2))) AS DECIMAL(12,6)) as ensemble_rmse,
    CASE
        WHEN SQRT(AVG(POWER(ensemble_prediction - {actual_column}, 2))) < 
             LEAST(
                 SQRT(AVG(POWER({predicted_col_model1} - {actual_column}, 2))),
                 SQRT(AVG(POWER({predicted_col_model2} - {actual_column}, 2))),
                 SQRT(AVG(POWER({predicted_col_model3} - {actual_column}, 2)))
             )
        THEN 'Ensemble wins'
        ELSE 'Individual model wins'
    END as winner
FROM ensemble;

-- =====================================================
-- Scenario 6: Use TD_RegressionEvaluator for Each Model
-- =====================================================

-- Evaluate Model 1
/*
DROP TABLE IF EXISTS {database}.model1_metrics;
CREATE MULTISET TABLE {database}.model1_metrics AS (
    SELECT 'Model 1' as model_name, * 
    FROM TD_RegressionEvaluator (
        ON (SELECT {id_column}, {actual_column} as actual_value, 
                   {predicted_col_model1} as predicted_value 
            FROM {database}.{multi_model_predictions_table}) AS InputTable
        USING
        ObservationColumn ('actual_value')
        PredictionColumn ('predicted_value')
        Metrics ('ALL')
    ) as dt
) WITH DATA;

-- Evaluate Model 2
DROP TABLE IF EXISTS {database}.model2_metrics;
CREATE MULTISET TABLE {database}.model2_metrics AS (
    SELECT 'Model 2' as model_name, * 
    FROM TD_RegressionEvaluator (
        ON (SELECT {id_column}, {actual_column} as actual_value, 
                   {predicted_col_model2} as predicted_value 
            FROM {database}.{multi_model_predictions_table}) AS InputTable
        USING
        ObservationColumn ('actual_value')
        PredictionColumn ('predicted_value')
        Metrics ('ALL')
    ) as dt
) WITH DATA;

-- Compare results
SELECT * FROM {database}.model1_metrics
UNION ALL
SELECT * FROM {database}.model2_metrics
ORDER BY model_name, metric_name;
*/

-- =====================================================
-- Usage Notes:
-- =====================================================
-- Replace placeholders:
--   {database} - Your database name
--   {multi_model_predictions_table} - Table with predictions from multiple models
--   {id_column} - Unique identifier
--   {actual_column} - Ground truth values
--   {predicted_col_model1} - Predictions from model 1
--   {predicted_col_model2} - Predictions from model 2
--   {predicted_col_model3} - Predictions from model 3
--
-- Model comparison strategies:
--   1. Overall metrics: Compare RMSE, MAE, R² across all data
--   2. Segment analysis: Check performance on different data ranges
--   3. Statistical testing: Determine if differences are significant
--   4. Ensemble methods: Combine models for better performance
--
-- Selection criteria:
--   - Lowest RMSE/MAE (better accuracy)
--   - Highest R² (better explanatory power)
--   - Consistent performance across segments
--   - Computational efficiency
--   - Model interpretability
-- =====================================================
