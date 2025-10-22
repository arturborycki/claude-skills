-- =====================================================
-- TD_GLMPredict - Prediction Script
-- =====================================================
-- Purpose: Generate predictions using trained GLM model
-- Input: Trained model table and test/new data
-- Output: Predictions with link function applied
-- =====================================================

-- Step 1: Verify model exists
SELECT * FROM {model_database}.glm_model_out;

-- Step 2: Generate predictions on test set
DROP TABLE IF EXISTS {output_database}.predictions_out;
CREATE MULTISET TABLE {output_database}.predictions_out AS (
    SELECT * FROM TD_GLMPredict (
        ON {test_data_database}.{test_data_table} AS InputTable
        ON {model_database}.glm_model_out AS ModelTable DIMENSION
        USING
        IDColumn ('{id_column}')
        Accumulate ('{id_column}', '{target_column}')
    ) as dt
) WITH DATA;

-- Step 3: View prediction results
SELECT TOP 100
    {id_column},
    {target_column} as actual_value,
    prediction as predicted_value,
    (prediction - {target_column}) as residual,
    ABS(prediction - {target_column}) as absolute_error
FROM {output_database}.predictions_out
ORDER BY absolute_error DESC;

-- Step 4: Calculate prediction summary statistics
SELECT
    COUNT(*) as total_predictions,
    AVG(prediction) as avg_prediction,
    STDDEV(prediction) as stddev_prediction,
    MIN(prediction) as min_prediction,
    MAX(prediction) as max_prediction,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY prediction) as q1_prediction,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY prediction) as median_prediction,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY prediction) as q3_prediction
FROM {output_database}.predictions_out;

-- Step 5: Model performance metrics
-- For regression (Gaussian family)
SELECT
    'Regression Metrics' as metric_type,
    COUNT(*) as n_predictions,
    -- Mean Squared Error
    AVG(POWER(prediction - {target_column}, 2)) as mse,
    -- Root Mean Squared Error
    SQRT(AVG(POWER(prediction - {target_column}, 2))) as rmse,
    -- Mean Absolute Error
    AVG(ABS(prediction - {target_column})) as mae,
    -- R-squared
    1 - (SUM(POWER(prediction - {target_column}, 2)) /
         SUM(POWER({target_column} - AVG({target_column}) OVER(), 2))) as r_squared,
    -- Mean Absolute Percentage Error
    AVG(ABS((prediction - {target_column}) / NULLIF({target_column}, 0))) * 100 as mape
FROM {output_database}.predictions_out;

-- Step 6: Residual distribution analysis
SELECT
    CASE
        WHEN (prediction - {target_column}) < -3 * STDDEV({target_column}) OVER() THEN 'Large Underestimate'
        WHEN (prediction - {target_column}) < -1 * STDDEV({target_column}) OVER() THEN 'Moderate Underestimate'
        WHEN (prediction - {target_column}) <= 1 * STDDEV({target_column}) OVER() THEN 'Good Fit'
        WHEN (prediction - {target_column}) <= 3 * STDDEV({target_column}) OVER() THEN 'Moderate Overestimate'
        ELSE 'Large Overestimate'
    END as prediction_category,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {output_database}.predictions_out
GROUP BY 1
ORDER BY count DESC;

-- Step 7: Identify outlier predictions
SELECT
    {id_column},
    {target_column} as actual,
    prediction as predicted,
    (prediction - {target_column}) as residual,
    ABS(prediction - {target_column}) / STDDEV({target_column}) OVER() as standardized_residual
FROM {output_database}.predictions_out
WHERE ABS(prediction - {target_column}) > 3 * STDDEV({target_column}) OVER()
ORDER BY ABS(prediction - {target_column}) DESC;

-- Step 8: Prediction by target value range
SELECT
    CASE
        WHEN {target_column} <= PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {target_column}) OVER() THEN 'Q1 (Low)'
        WHEN {target_column} <= PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY {target_column}) OVER() THEN 'Q2 (Medium-Low)'
        WHEN {target_column} <= PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {target_column}) OVER() THEN 'Q3 (Medium-High)'
        ELSE 'Q4 (High)'
    END as target_quartile,
    COUNT(*) as count,
    AVG({target_column}) as avg_actual,
    AVG(prediction) as avg_predicted,
    AVG(ABS(prediction - {target_column})) as avg_abs_error,
    SQRT(AVG(POWER(prediction - {target_column}, 2))) as rmse
FROM {output_database}.predictions_out
GROUP BY 1
ORDER BY
    CASE
        WHEN {target_column} <= PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {target_column}) OVER() THEN 1
        WHEN {target_column} <= PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY {target_column}) OVER() THEN 2
        WHEN {target_column} <= PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {target_column}) OVER() THEN 3
        ELSE 4
    END;

-- =====================================================
-- For Binomial/Classification (if applicable)
-- =====================================================

-- Step 9: Classification metrics (if using binomial family)
/*
SELECT
    'Classification Metrics' as metric_type,
    COUNT(*) as total_predictions,
    SUM(CASE WHEN prediction = {target_column} THEN 1 ELSE 0 END) as correct_predictions,
    CAST(SUM(CASE WHEN prediction = {target_column} THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as accuracy_percentage
FROM {output_database}.predictions_out;

-- Confusion matrix for classification
SELECT
    {target_column} as actual_class,
    prediction as predicted_class,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY {target_column}) AS DECIMAL(5,2)) as percentage_of_actual
FROM {output_database}.predictions_out
GROUP BY {target_column}, prediction
ORDER BY {target_column}, prediction;
*/

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {model_database} - Database containing trained model
--    {test_data_database} - Database with test/new data
--    {test_data_table} - Table name for test/new data
--    {output_database} - Where to store predictions
--    {id_column} - Unique identifier column
--    {target_column} - Target variable column
--
-- 2. Prerequisites:
--    - Trained GLM model table must exist
--    - Test data must have same features as training data
--    - Features must be preprocessed identically to training
--
-- 3. Output interpretation:
--    - prediction: Predicted value (on response scale, not link scale)
--    - For Gaussian family: continuous predictions
--    - For Binomial family: class probabilities or binary predictions
--    - For Poisson family: count predictions
--
-- 4. Family-specific considerations:
--    - Gaussian (identity link): Standard linear regression
--    - Binomial (logit link): Logistic regression for classification
--    - Poisson (log link): Count data regression
--    - Gamma (inverse link): Positive continuous data with constant CV
--
-- =====================================================
