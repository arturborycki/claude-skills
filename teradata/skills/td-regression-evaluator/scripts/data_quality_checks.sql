-- =====================================================
-- TD_RegressionEvaluator - Data Quality Checks
-- =====================================================
-- Purpose: Validate data quality before evaluation
-- Checks: Completeness, outliers, data types, correlations
-- =====================================================

-- =====================================================
-- Check 1: Data Completeness
-- =====================================================

SELECT
    'Data Completeness Check' as check_name,
    COUNT(*) as total_records,
    COUNT({id_column}) as id_count,
    COUNT({actual_column}) as actual_non_null,
    COUNT({predicted_column}) as predicted_non_null,
    COUNT(*) - COUNT({actual_column}) as actual_nulls,
    COUNT(*) - COUNT({predicted_column}) as predicted_nulls,
    CASE
        WHEN COUNT({actual_column}) = COUNT(*)
         AND COUNT({predicted_column}) = COUNT(*)
        THEN 'PASS - No Missing Values'
        ELSE 'FAIL - Missing Values Detected'
    END as completeness_status
FROM {database}.{predictions_table};

-- =====================================================
-- Check 2: Data Type and Range Validation
-- =====================================================

SELECT
    'Actual Values' as column_type,
    CAST(MIN({actual_column}) AS DECIMAL(12,4)) as min_value,
    CAST(MAX({actual_column}) AS DECIMAL(12,4)) as max_value,
    CAST(AVG({actual_column}) AS DECIMAL(12,4)) as mean_value,
    CAST(STDDEV({actual_column}) AS DECIMAL(12,4)) as std_dev,
    COUNT(*) as count
FROM {database}.{predictions_table}
WHERE {actual_column} IS NOT NULL

UNION ALL

SELECT
    'Predicted Values' as column_type,
    CAST(MIN({predicted_column}) AS DECIMAL(12,4)) as min_value,
    CAST(MAX({predicted_column}) AS DECIMAL(12,4)) as max_value,
    CAST(AVG({predicted_column}) AS DECIMAL(12,4)) as mean_value,
    CAST(STDDEV({predicted_column}) AS DECIMAL(12,4)) as std_dev,
    COUNT(*) as count
FROM {database}.{predictions_table}
WHERE {predicted_column} IS NOT NULL;

-- =====================================================
-- Check 3: Duplicate ID Detection
-- =====================================================

SELECT
    'Duplicate Check' as check_name,
    COUNT(*) as duplicate_groups,
    SUM(duplicate_count) as total_duplicates
FROM (
    SELECT
        {id_column},
        COUNT(*) as duplicate_count
    FROM {database}.{predictions_table}
    GROUP BY {id_column}
    HAVING COUNT(*) > 1
) dup;

-- List duplicate IDs if any exist
SELECT
    {id_column},
    COUNT(*) as occurrence_count
FROM {database}.{predictions_table}
GROUP BY {id_column}
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC;

-- =====================================================
-- Check 4: Outlier Detection (IQR Method)
-- =====================================================

WITH stats AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {actual_column}) as q1_actual,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {actual_column}) as q3_actual,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {predicted_column}) as q1_predicted,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {predicted_column}) as q3_predicted
    FROM {database}.{predictions_table}
),
outlier_bounds AS (
    SELECT
        q1_actual - 1.5 * (q3_actual - q1_actual) as lower_bound_actual,
        q3_actual + 1.5 * (q3_actual - q1_actual) as upper_bound_actual,
        q1_predicted - 1.5 * (q3_predicted - q1_predicted) as lower_bound_predicted,
        q3_predicted + 1.5 * (q3_predicted - q1_predicted) as upper_bound_predicted
    FROM stats
)
SELECT
    'Outlier Analysis (IQR Method)' as check_name,
    (SELECT COUNT(*) FROM {database}.{predictions_table}) as total_records,
    COUNT(CASE WHEN {actual_column} < lower_bound_actual OR {actual_column} > upper_bound_actual THEN 1 END) as actual_outliers,
    COUNT(CASE WHEN {predicted_column} < lower_bound_predicted OR {predicted_column} > upper_bound_predicted THEN 1 END) as predicted_outliers,
    CAST(COUNT(CASE WHEN {actual_column} < lower_bound_actual OR {actual_column} > upper_bound_actual THEN 1 END) * 100.0 /
         (SELECT COUNT(*) FROM {database}.{predictions_table}) AS DECIMAL(5,2)) as actual_outlier_pct,
    CAST(COUNT(CASE WHEN {predicted_column} < lower_bound_predicted OR {predicted_column} > upper_bound_predicted THEN 1 END) * 100.0 /
         (SELECT COUNT(*) FROM {database}.{predictions_table}) AS DECIMAL(5,2)) as predicted_outlier_pct
FROM {database}.{predictions_table}, outlier_bounds;

-- =====================================================
-- Check 5: Outlier Detection (Standard Deviation Method)
-- =====================================================

WITH stats AS (
    SELECT
        AVG({actual_column}) as mean_actual,
        STDDEV({actual_column}) as std_actual,
        AVG({predicted_column}) as mean_predicted,
        STDDEV({predicted_column}) as std_predicted
    FROM {database}.{predictions_table}
)
SELECT
    'Outlier Analysis (3 Sigma Method)' as check_name,
    COUNT(*) as total_records,
    SUM(CASE WHEN ABS({actual_column} - mean_actual) > 3 * std_actual THEN 1 ELSE 0 END) as actual_outliers_3sigma,
    SUM(CASE WHEN ABS({predicted_column} - mean_predicted) > 3 * std_predicted THEN 1 ELSE 0 END) as predicted_outliers_3sigma,
    CAST(SUM(CASE WHEN ABS({actual_column} - mean_actual) > 3 * std_actual THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as actual_outlier_pct,
    CAST(SUM(CASE WHEN ABS({predicted_column} - mean_predicted) > 3 * std_predicted THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as predicted_outlier_pct
FROM {database}.{predictions_table}, stats;

-- =====================================================
-- Check 6: Sample Size Adequacy
-- =====================================================

SELECT
    'Sample Size Check' as check_name,
    COUNT(*) as sample_size,
    CASE
        WHEN COUNT(*) >= 100 THEN 'Excellent (>= 100)'
        WHEN COUNT(*) >= 50 THEN 'Good (50-99)'
        WHEN COUNT(*) >= 30 THEN 'Acceptable (30-49)'
        ELSE 'Insufficient (< 30)'
    END as sample_size_status,
    CASE
        WHEN COUNT(*) >= 30 THEN 'PASS'
        ELSE 'FAIL - Insufficient sample size for reliable metrics'
    END as check_result
FROM {database}.{predictions_table};

-- =====================================================
-- Check 7: Data Consistency (Actual vs Predicted Ranges)
-- =====================================================

WITH ranges AS (
    SELECT
        MIN({actual_column}) as min_actual,
        MAX({actual_column}) as max_actual,
        MIN({predicted_column}) as min_predicted,
        MAX({predicted_column}) as max_predicted,
        AVG({actual_column}) as avg_actual,
        AVG({predicted_column}) as avg_predicted
    FROM {database}.{predictions_table}
)
SELECT
    'Range Consistency Check' as check_name,
    CAST(min_actual AS DECIMAL(12,4)) as min_actual,
    CAST(min_predicted AS DECIMAL(12,4)) as min_predicted,
    CAST(max_actual AS DECIMAL(12,4)) as max_actual,
    CAST(max_predicted AS DECIMAL(12,4)) as max_predicted,
    CAST(ABS(avg_actual - avg_predicted) AS DECIMAL(12,4)) as mean_difference,
    CASE
        WHEN ABS(avg_actual - avg_predicted) / NULLIF(avg_actual, 0) > 0.5
        THEN 'WARNING - Large difference between actual and predicted means'
        ELSE 'PASS - Means are reasonably similar'
    END as consistency_status
FROM ranges;

-- =====================================================
-- Check 8: Correlation Pre-Check
-- =====================================================

SELECT
    'Correlation Check' as check_name,
    CAST(CORR({actual_column}, {predicted_column}) AS DECIMAL(10,6)) as correlation,
    CASE
        WHEN CORR({actual_column}, {predicted_column}) > 0.7 THEN 'PASS - Good correlation (>0.7)'
        WHEN CORR({actual_column}, {predicted_column}) > 0.5 THEN 'ACCEPTABLE - Moderate correlation (0.5-0.7)'
        WHEN CORR({actual_column}, {predicted_column}) > 0 THEN 'WARNING - Weak correlation (0-0.5)'
        ELSE 'FAIL - Negative or zero correlation'
    END as correlation_status
FROM {database}.{predictions_table};

-- =====================================================
-- Check 9: Zero and Negative Value Detection
-- =====================================================

SELECT
    'Zero/Negative Value Check' as check_name,
    SUM(CASE WHEN {actual_column} = 0 THEN 1 ELSE 0 END) as actual_zeros,
    SUM(CASE WHEN {predicted_column} = 0 THEN 1 ELSE 0 END) as predicted_zeros,
    SUM(CASE WHEN {actual_column} < 0 THEN 1 ELSE 0 END) as actual_negatives,
    SUM(CASE WHEN {predicted_column} < 0 THEN 1 ELSE 0 END) as predicted_negatives,
    CASE
        WHEN SUM(CASE WHEN {actual_column} = 0 THEN 1 ELSE 0 END) > 0
        THEN 'WARNING - Zero values present (MAPE will be affected)'
        ELSE 'PASS - No zero values'
    END as mape_compatibility
FROM {database}.{predictions_table};

-- =====================================================
-- Check 10: Overall Quality Summary
-- =====================================================

SELECT
    'Overall Data Quality Summary' as summary_type,
    COUNT(*) as total_records,
    COUNT({actual_column}) as valid_actual,
    COUNT({predicted_column}) as valid_predicted,
    CASE
        WHEN COUNT(*) >= 30
            AND COUNT({actual_column}) = COUNT(*)
            AND COUNT({predicted_column}) = COUNT(*)
            AND CORR({actual_column}, {predicted_column}) > 0.3
        THEN 'PASS - Ready for TD_RegressionEvaluator'
        WHEN COUNT(*) < 30 THEN 'FAIL - Insufficient sample size'
        WHEN COUNT({actual_column}) < COUNT(*) OR COUNT({predicted_column}) < COUNT(*) THEN 'FAIL - Missing values present'
        WHEN CORR({actual_column}, {predicted_column}) <= 0.3 THEN 'WARNING - Very weak correlation'
        ELSE 'REVIEW REQUIRED'
    END as overall_status
FROM {database}.{predictions_table};

-- =====================================================
-- Usage Notes:
-- =====================================================
-- Replace placeholders:
--   {database} - Your database name
--   {predictions_table} - Table with actual and predicted values
--   {id_column} - Unique identifier column
--   {actual_column} - Ground truth values
--   {predicted_column} - Model predictions
--
-- All checks should PASS before running TD_RegressionEvaluator
-- Address any FAIL or WARNING status before proceeding
--
-- Common issues:
--   - Missing values: Remove or impute
--   - Duplicates: Investigate and deduplicate
--   - Outliers: Consider robust metrics or data cleaning
--   - Weak correlation: Review model quality
--   - Small sample: Collect more data
-- =====================================================
