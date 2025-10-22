-- =====================================================
-- TD_RegressionEvaluator - Data Preprocessing
-- =====================================================
-- Purpose: Prepare evaluation data for regression model assessment
-- Function: TD_RegressionEvaluator
-- Note: This is for EVALUATION only, not model training
-- =====================================================

-- =====================================================
-- Step 1: Verify Input Data Structure
-- =====================================================

-- Check the structure of your predictions table
-- TD_RegressionEvaluator requires:
-- 1. ID column (to match predictions with actuals)
-- 2. Actual value column (ground truth)
-- 3. Predicted value column (model output)

SELECT TOP 10
    {id_column},
    {actual_column},
    {predicted_column}
FROM {database}.{predictions_table}
ORDER BY {id_column};

-- =====================================================
-- Step 2: Data Completeness Check
-- =====================================================

-- Verify no missing values in required columns
SELECT
    COUNT(*) as total_records,
    COUNT({id_column}) as id_count,
    COUNT({actual_column}) as actual_count,
    COUNT({predicted_column}) as predicted_count,
    COUNT(*) - COUNT({actual_column}) as missing_actual,
    COUNT(*) - COUNT({predicted_column}) as missing_predicted,
    CASE
        WHEN COUNT({actual_column}) = COUNT(*)
         AND COUNT({predicted_column}) = COUNT(*)
        THEN 'READY FOR EVALUATION'
        ELSE 'MISSING VALUES DETECTED'
    END as data_status
FROM {database}.{predictions_table};

-- =====================================================
-- Step 3: Check for Duplicate IDs
-- =====================================================

-- Ensure each ID appears only once
SELECT
    {id_column},
    COUNT(*) as occurrence_count
FROM {database}.{predictions_table}
GROUP BY {id_column}
HAVING COUNT(*) > 1;

-- If duplicates exist, decide on resolution strategy:
-- Option 1: Keep first occurrence
-- Option 2: Average predictions
-- Option 3: Investigate data source

-- =====================================================
-- Step 4: Create Clean Evaluation Dataset
-- =====================================================

-- Prepare clean dataset for TD_RegressionEvaluator
DROP TABLE IF EXISTS {database}.regression_evaluation_input;
CREATE MULTISET TABLE {database}.regression_evaluation_input AS (
    SELECT
        {id_column},
        CAST({actual_column} AS FLOAT) as actual_value,
        CAST({predicted_column} AS FLOAT) as predicted_value
    FROM {database}.{predictions_table}
    WHERE {actual_column} IS NOT NULL
      AND {predicted_column} IS NOT NULL
      AND {id_column} IS NOT NULL
) WITH DATA;

-- =====================================================
-- Step 5: Statistical Summary of Data
-- =====================================================

-- Compare distributions of actual vs predicted values
SELECT
    'Summary Statistics' as report_section,
    COUNT(*) as n_observations,
    -- Actual Values
    CAST(MIN(actual_value) AS DECIMAL(12,4)) as min_actual,
    CAST(MAX(actual_value) AS DECIMAL(12,4)) as max_actual,
    CAST(AVG(actual_value) AS DECIMAL(12,4)) as mean_actual,
    CAST(STDDEV(actual_value) AS DECIMAL(12,4)) as std_actual,
    -- Predicted Values
    CAST(MIN(predicted_value) AS DECIMAL(12,4)) as min_predicted,
    CAST(MAX(predicted_value) AS DECIMAL(12,4)) as max_predicted,
    CAST(AVG(predicted_value) AS DECIMAL(12,4)) as mean_predicted,
    CAST(STDDEV(predicted_value) AS DECIMAL(12,4)) as std_predicted
FROM {database}.regression_evaluation_input;

-- =====================================================
-- Step 6: Distribution Analysis by Deciles
-- =====================================================

-- Analyze actual vs predicted distribution alignment
SELECT
    'Actual' as value_type,
    NTILE(10) OVER (ORDER BY actual_value) as decile,
    COUNT(*) as count,
    CAST(MIN(actual_value) AS DECIMAL(12,4)) as min_value,
    CAST(MAX(actual_value) AS DECIMAL(12,4)) as max_value,
    CAST(AVG(actual_value) AS DECIMAL(12,4)) as avg_value
FROM {database}.regression_evaluation_input
GROUP BY 2

UNION ALL

SELECT
    'Predicted' as value_type,
    NTILE(10) OVER (ORDER BY predicted_value) as decile,
    COUNT(*) as count,
    CAST(MIN(predicted_value) AS DECIMAL(12,4)) as min_value,
    CAST(MAX(predicted_value) AS DECIMAL(12,4)) as max_value,
    CAST(AVG(predicted_value) AS DECIMAL(12,4)) as avg_value
FROM {database}.regression_evaluation_input
GROUP BY 2

ORDER BY value_type, decile;

-- =====================================================
-- Step 7: Initial Correlation Check
-- =====================================================

-- Strong correlation suggests model is learning patterns
SELECT
    CAST(CORR(actual_value, predicted_value) AS DECIMAL(10,6)) as correlation,
    CASE
        WHEN CORR(actual_value, predicted_value) > 0.9 THEN 'Excellent Correlation'
        WHEN CORR(actual_value, predicted_value) > 0.7 THEN 'Good Correlation'
        WHEN CORR(actual_value, predicted_value) > 0.5 THEN 'Moderate Correlation'
        WHEN CORR(actual_value, predicted_value) > 0 THEN 'Weak Correlation'
        ELSE 'Poor/Negative Correlation'
    END as correlation_assessment
FROM {database}.regression_evaluation_input;

-- =====================================================
-- Step 8: Outlier Detection
-- =====================================================

-- Identify extreme values that might affect metrics
WITH stats AS (
    SELECT
        AVG(actual_value) as mean_actual,
        STDDEV(actual_value) as std_actual,
        AVG(predicted_value) as mean_predicted,
        STDDEV(predicted_value) as std_predicted
    FROM {database}.regression_evaluation_input
)
SELECT
    'Outlier Analysis' as report_section,
    COUNT(*) as total_records,
    SUM(CASE WHEN ABS(actual_value - mean_actual) > 3 * std_actual THEN 1 ELSE 0 END) as actual_outliers,
    SUM(CASE WHEN ABS(predicted_value - mean_predicted) > 3 * std_predicted THEN 1 ELSE 0 END) as predicted_outliers,
    CAST(SUM(CASE WHEN ABS(actual_value - mean_actual) > 3 * std_actual THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as actual_outlier_pct,
    CAST(SUM(CASE WHEN ABS(predicted_value - mean_predicted) > 3 * std_predicted THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as predicted_outlier_pct
FROM {database}.regression_evaluation_input, stats;

-- =====================================================
-- Step 9: Quick Manual Metric Calculation
-- =====================================================

-- Calculate basic metrics manually for verification
SELECT
    'Quick Metrics Check' as report_section,
    COUNT(*) as n_samples,
    CAST(SQRT(AVG(POWER(predicted_value - actual_value, 2))) AS DECIMAL(12,6)) as rmse,
    CAST(AVG(ABS(predicted_value - actual_value)) AS DECIMAL(12,6)) as mae,
    CAST(1 - (SUM(POWER(predicted_value - actual_value, 2)) /
         NULLIF(SUM(POWER(actual_value - AVG(actual_value) OVER(), 2)), 0)) AS DECIMAL(10,6)) as r_squared
FROM {database}.regression_evaluation_input;

-- =====================================================
-- Step 10: Final Readiness Check
-- =====================================================

-- Confirm data is ready for TD_RegressionEvaluator
SELECT
    'Preprocessing Status' as check_type,
    (SELECT COUNT(*) FROM {database}.regression_evaluation_input) as prepared_records,
    CASE
        WHEN (SELECT COUNT(*) FROM {database}.regression_evaluation_input) >= 30
         AND (SELECT COUNT(*) FROM {database}.regression_evaluation_input WHERE actual_value IS NULL OR predicted_value IS NULL) = 0
        THEN 'READY FOR TD_RegressionEvaluator'
        ELSE 'REVIEW REQUIRED'
    END as status,
    CASE
        WHEN (SELECT COUNT(*) FROM {database}.regression_evaluation_input) < 30 THEN 'Insufficient sample size (min 30)'
        WHEN (SELECT COUNT(*) FROM {database}.regression_evaluation_input WHERE actual_value IS NULL OR predicted_value IS NULL) > 0 THEN 'NULL values present'
        ELSE 'All checks passed'
    END as notes;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- Replace placeholders:
--   {database} - Your database name
--   {predictions_table} - Table containing predictions and actuals
--   {id_column} - Unique identifier column
--   {actual_column} - Ground truth values
--   {predicted_column} - Model predictions
--
-- Data requirements:
--   - Minimum 30 observations recommended
--   - No NULL values in actual or predicted columns
--   - Both columns must be numeric (will be cast to FLOAT)
--   - Same scale/units for meaningful metrics
--
-- Next step: Run evaluation.sql to execute TD_RegressionEvaluator
-- =====================================================
