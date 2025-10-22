-- =====================================================
-- Data Quality Checks - Comprehensive Validation
-- =====================================================
-- Purpose: Validate data quality before GLM analysis
-- Checks: Completeness, accuracy, consistency, validity
-- Note: Applies to both regression and classification GLM
-- =====================================================

-- =====================================================
-- 1. BASIC DATA PROFILING
-- =====================================================

-- Check total record count and unique records
SELECT
    COUNT(*) as total_records,
    COUNT(DISTINCT {id_column}) as unique_records,
    COUNT(*) - COUNT(DISTINCT {id_column}) as duplicate_count,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT {id_column}) THEN 'PASS'
        ELSE 'FAIL - Duplicates Found'
    END as duplicate_check
FROM {database}.{table_name};

-- =====================================================
-- 2. MISSING VALUE ANALYSIS
-- =====================================================

-- Check for NULL values in all columns
SELECT
    'Target: {target_column}' as column_name,
    COUNT(*) as total_rows,
    COUNT({target_column}) as non_null_count,
    COUNT(*) - COUNT({target_column}) as null_count,
    CAST((COUNT(*) - COUNT({target_column})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as null_percentage,
    CASE
        WHEN COUNT({target_column}) = COUNT(*) THEN 'PASS'
        WHEN CAST((COUNT(*) - COUNT({target_column})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) < 5 THEN 'WARNING'
        ELSE 'FAIL'
    END as quality_status
FROM {database}.{table_name}

UNION ALL

-- Add checks for each numeric feature column
SELECT
    'Feature: {numeric_column_1}' as column_name,
    COUNT(*) as total_rows,
    COUNT({numeric_column_1}) as non_null_count,
    COUNT(*) - COUNT({numeric_column_1}) as null_count,
    CAST((COUNT(*) - COUNT({numeric_column_1})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as null_percentage,
    CASE
        WHEN COUNT({numeric_column_1}) = COUNT(*) THEN 'PASS'
        WHEN CAST((COUNT(*) - COUNT({numeric_column_1})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) < 5 THEN 'WARNING'
        ELSE 'FAIL'
    END as quality_status
FROM {database}.{table_name};

-- =====================================================
-- 3. TARGET VARIABLE VALIDATION
-- =====================================================

-- For Gaussian GLM (Regression)
-- Analyze target variable distribution
SELECT
    COUNT(*) as total_records,
    COUNT({target_column}) as non_null_count,
    AVG({target_column}) as mean_value,
    STDDEV({target_column}) as std_dev,
    MIN({target_column}) as min_value,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {target_column}) as q1,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY {target_column}) as median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {target_column}) as q3,
    MAX({target_column}) as max_value,
    -- Check for constant target (no variance)
    CASE
        WHEN STDDEV({target_column}) > 0 THEN 'PASS - Has Variance'
        ELSE 'FAIL - Constant Target'
    END as variance_check,
    -- Check for sufficient sample size
    CASE
        WHEN COUNT({target_column}) >= 100 THEN 'PASS - Sufficient Sample'
        WHEN COUNT({target_column}) >= 50 THEN 'WARNING - Small Sample'
        ELSE 'FAIL - Insufficient Sample'
    END as sample_size_check
FROM {database}.{table_name};

-- For Binomial GLM (Classification)
-- Check binary target distribution
/*
SELECT
    {target_column} as class_value,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    CASE
        WHEN CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) < 10 THEN 'WARNING - Rare Class'
        WHEN CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) > 90 THEN 'WARNING - Dominant Class'
        ELSE 'PASS - Balanced'
    END as balance_check
FROM {database}.{table_name}
WHERE {target_column} IS NOT NULL
GROUP BY {target_column}
ORDER BY count DESC;
*/

-- For Poisson GLM (Count Data)
-- Check if target is non-negative integer
/*
SELECT
    COUNT(*) as total_records,
    SUM(CASE WHEN {target_column} < 0 THEN 1 ELSE 0 END) as negative_values,
    SUM(CASE WHEN {target_column} - CAST({target_column} AS INTEGER) <> 0 THEN 1 ELSE 0 END) as non_integer_values,
    AVG({target_column}) as mean_count,
    VARIANCE({target_column}) as variance_count,
    CAST(VARIANCE({target_column}) / NULLIF(AVG({target_column}), 0) AS DECIMAL(10,2)) as dispersion_ratio,
    CASE
        WHEN SUM(CASE WHEN {target_column} < 0 THEN 1 ELSE 0 END) = 0 THEN 'PASS - All Non-Negative'
        ELSE 'FAIL - Negative Values Present'
    END as non_negative_check,
    CASE
        WHEN ABS(VARIANCE({target_column}) / NULLIF(AVG({target_column}), 0) - 1) < 0.5 THEN 'PASS - Equidispersed'
        WHEN VARIANCE({target_column}) / NULLIF(AVG({target_column}), 0) > 1 THEN 'WARNING - Overdispersed'
        ELSE 'WARNING - Underdispersed'
    END as dispersion_check
FROM {database}.{table_name};
*/

-- Detect outliers in target variable using IQR method
WITH stats AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {target_column}) as q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {target_column}) as q3
    FROM {database}.{table_name}
),
outlier_bounds AS (
    SELECT
        q1,
        q3,
        (q3 - q1) as iqr,
        q1 - 1.5 * (q3 - q1) as lower_bound,
        q3 + 1.5 * (q3 - q1) as upper_bound
    FROM stats
)
SELECT
    COUNT(*) as total_outliers,
    SUM(CASE WHEN {target_column} < lower_bound THEN 1 ELSE 0 END) as lower_outliers,
    SUM(CASE WHEN {target_column} > upper_bound THEN 1 ELSE 0 END) as upper_outliers,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name}) AS DECIMAL(5,2)) as outlier_percentage,
    lower_bound,
    upper_bound,
    CASE
        WHEN COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name}) < 5 THEN 'PASS'
        WHEN COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name}) < 10 THEN 'WARNING'
        ELSE 'FAIL - Too Many Outliers'
    END as outlier_check
FROM {database}.{table_name}, outlier_bounds
WHERE {target_column} < lower_bound OR {target_column} > upper_bound;

-- =====================================================
-- 4. FEATURE VARIABLE VALIDATION
-- =====================================================

-- Check numeric features for invalid values
SELECT
    '{numeric_column_1}' as feature_name,
    COUNT(*) as total_values,
    SUM(CASE WHEN {numeric_column_1} IS NULL THEN 1 ELSE 0 END) as null_count,
    SUM(CASE WHEN {numeric_column_1} = 0 THEN 1 ELSE 0 END) as zero_count,
    SUM(CASE WHEN {numeric_column_1} < 0 THEN 1 ELSE 0 END) as negative_count,
    MIN({numeric_column_1}) as min_value,
    MAX({numeric_column_1}) as max_value,
    AVG({numeric_column_1}) as mean_value,
    STDDEV({numeric_column_1}) as std_dev,
    CASE
        WHEN STDDEV({numeric_column_1}) = 0 THEN 'FAIL - No Variance'
        WHEN STDDEV({numeric_column_1}) IS NULL THEN 'FAIL - All Nulls'
        ELSE 'PASS'
    END as variance_check
FROM {database}.{table_name};

-- Check for highly correlated features (multicollinearity warning)
SELECT
    '{numeric_column_1}' as feature_1,
    '{numeric_column_2}' as feature_2,
    CORR({numeric_column_1}, {numeric_column_2}) as correlation_coefficient,
    CASE
        WHEN ABS(CORR({numeric_column_1}, {numeric_column_2})) > 0.95 THEN 'FAIL - Extreme Correlation'
        WHEN ABS(CORR({numeric_column_1}, {numeric_column_2})) > 0.9 THEN 'WARNING - High Correlation'
        ELSE 'PASS'
    END as multicollinearity_check
FROM {database}.{table_name};

-- Variance Inflation Factor (VIF) check would require additional computation
-- High VIF (>10) indicates problematic multicollinearity

-- =====================================================
-- 5. CATEGORICAL VARIABLE VALIDATION
-- =====================================================

-- Check categorical variable cardinality
SELECT
    '{categorical_column}' as column_name,
    COUNT(DISTINCT {categorical_column}) as unique_values,
    COUNT(*) as total_records,
    CAST(COUNT(DISTINCT {categorical_column}) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as cardinality_percentage,
    CASE
        WHEN COUNT(DISTINCT {categorical_column}) = 1 THEN 'FAIL - Single Value'
        WHEN COUNT(DISTINCT {categorical_column}) > 50 THEN 'WARNING - High Cardinality'
        WHEN COUNT(DISTINCT {categorical_column}) > 100 THEN 'FAIL - Too Many Categories'
        ELSE 'PASS'
    END as cardinality_check
FROM {database}.{table_name};

-- Check categorical value distribution (imbalance)
SELECT
    {categorical_column} as category_value,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    CASE
        WHEN CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) < 1 THEN 'WARNING - Rare Category'
        ELSE 'PASS'
    END as balance_check
FROM {database}.{table_name}
WHERE {categorical_column} IS NOT NULL
GROUP BY {categorical_column}
ORDER BY count DESC;

-- =====================================================
-- 6. DATA CONSISTENCY CHECKS
-- =====================================================

-- Check for duplicate records based on ID
SELECT
    {id_column},
    COUNT(*) as duplicate_count
FROM {database}.{table_name}
GROUP BY {id_column}
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Check for logical inconsistencies
-- Customize this based on business rules and GLM family
SELECT
    COUNT(*) as inconsistent_records,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name}) AS DECIMAL(5,2)) as inconsistency_percentage
FROM {database}.{table_name}
WHERE
    {numeric_column_1} < 0  -- Example: Some features should be non-negative
    OR {numeric_column_2} > 1000  -- Example: Reasonable upper bound
    OR ({categorical_column} NOT IN ('expected_value_1', 'expected_value_2'))  -- Example: Valid categories
;

-- =====================================================
-- 7. GLM-SPECIFIC CHECKS
-- =====================================================

-- Check for separation issues in binary classification
-- Complete or quasi-complete separation makes GLM unstable
/*
WITH feature_class_combos AS (
    SELECT
        {categorical_column} as feature_value,
        {target_column} as target_value,
        COUNT(*) as count
    FROM {database}.{table_name}
    GROUP BY {categorical_column}, {target_column}
)
SELECT
    feature_value,
    SUM(CASE WHEN target_value = 0 THEN count ELSE 0 END) as class_0_count,
    SUM(CASE WHEN target_value = 1 THEN count ELSE 0 END) as class_1_count,
    CASE
        WHEN SUM(CASE WHEN target_value = 0 THEN count ELSE 0 END) = 0 THEN 'WARNING - Complete Separation'
        WHEN SUM(CASE WHEN target_value = 1 THEN count ELSE 0 END) = 0 THEN 'WARNING - Complete Separation'
        ELSE 'PASS'
    END as separation_check
FROM feature_class_combos
GROUP BY feature_value;
*/

-- =====================================================
-- 8. SAMPLE SIZE ADEQUACY
-- =====================================================

-- Check if sample size is adequate for GLM
WITH feature_count AS (
    SELECT
        -- Count number of features (update based on your actual feature count)
        10 as num_features
),
sample_stats AS (
    SELECT
        COUNT(*) as total_samples,
        (SELECT num_features FROM feature_count) as num_features,
        -- Rule of thumb for GLM: need at least 10-20 samples per parameter
        (SELECT num_features FROM feature_count) * 20 as recommended_min_samples
    FROM {database}.{table_name}
)
SELECT
    total_samples,
    num_features,
    recommended_min_samples,
    CAST(total_samples * 1.0 / num_features AS DECIMAL(10,2)) as samples_per_feature,
    CASE
        WHEN total_samples >= recommended_min_samples THEN 'PASS - Adequate Sample Size'
        WHEN total_samples >= num_features * 10 THEN 'WARNING - Minimum Sample Size'
        ELSE 'FAIL - Insufficient Sample Size'
    END as sample_adequacy_check
FROM sample_stats;

-- =====================================================
-- 9. COMPREHENSIVE QUALITY SUMMARY
-- =====================================================

-- Generate overall data quality report
SELECT
    'Data Quality Summary' as report_section,
    COUNT(*) as total_records,
    COUNT(DISTINCT {id_column}) as unique_records,
    COUNT({target_column}) as target_non_null,
    CAST((COUNT(*) - COUNT({target_column})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as target_null_pct,
    STDDEV({target_column}) as target_std_dev,
    CASE
        WHEN COUNT(*) >= 100
            AND COUNT(*) = COUNT(DISTINCT {id_column})
            AND COUNT({target_column}) = COUNT(*)
            AND STDDEV({target_column}) > 0
        THEN 'PASS - Ready for Analysis'
        ELSE 'REVIEW REQUIRED - Check Individual Tests'
    END as overall_quality_status
FROM {database}.{table_name};

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {table_name} - Your table name
--    {id_column} - Unique identifier column
--    {target_column} - Target variable for GLM
--    {numeric_column_1}, {numeric_column_2}, etc. - Feature columns
--    {categorical_column} - Categorical feature column
--
-- 2. Uncomment sections based on GLM family:
--    - Gaussian: Keep regression checks
--    - Binomial: Uncomment classification checks
--    - Poisson: Uncomment count data checks
--    - Gamma: Similar to Gaussian but ensure positive target
--
-- 3. Run each section sequentially to identify issues
--
-- 4. Address any FAIL or WARNING statuses before modeling:
--    - Handle missing values (imputation or removal)
--    - Remove or transform outliers
--    - Address duplicates
--    - Fix data inconsistencies
--    - Check for multicollinearity (VIF analysis)
--    - Address separation issues (binomial GLM)
--    - Ensure adequate sample size
--
-- 5. Document any data quality decisions made
--
-- =====================================================
