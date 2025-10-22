-- =====================================================
-- Data Quality Checks - Classification Data Validation
-- =====================================================
-- Purpose: Validate data quality before naive bayes modeling
-- Checks: Completeness, class balance, feature validity
-- =====================================================

-- =====================================================
-- 1. BASIC DATA PROFILING
-- =====================================================

SELECT
    COUNT(*) as total_records,
    COUNT(DISTINCT {id_column}) as unique_ids,
    COUNT(*) - COUNT(DISTINCT {id_column}) as duplicate_count,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT {id_column}) THEN 'PASS'
        ELSE 'FAIL - Duplicates Found'
    END as duplicate_check
FROM {database}.{table_name};

-- =====================================================
-- 2. TARGET VARIABLE VALIDATION
-- =====================================================

-- Check target variable completeness and distribution
SELECT
    COUNT(*) as total_records,
    COUNT({target_column}) as non_null_targets,
    COUNT(DISTINCT {target_column}) as num_classes,
    CAST((COUNT(*) - COUNT({target_column})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as null_percentage,
    CASE
        WHEN COUNT({target_column}) = COUNT(*) THEN 'PASS'
        WHEN COUNT({target_column}) > 0.95 * COUNT(*) THEN 'WARNING - Some Nulls'
        ELSE 'FAIL - Too Many Nulls'
    END as completeness_check,
    CASE
        WHEN COUNT(DISTINCT {target_column}) >= 2 THEN 'PASS - Multi-class'
        ELSE 'FAIL - Insufficient Classes'
    END as class_check
FROM {database}.{table_name};

-- Analyze class distribution and balance
SELECT
    {target_column} as class_label,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    CASE
        WHEN CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) < 5 THEN 'WARNING - Underrepresented'
        WHEN CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) > 70 THEN 'WARNING - Dominant Class'
        ELSE 'PASS'
    END as balance_check
FROM {database}.{table_name}
WHERE {target_column} IS NOT NULL
GROUP BY {target_column}
ORDER BY count DESC;

-- Class imbalance ratio
WITH class_counts AS (
    SELECT
        {target_column},
        COUNT(*) as cnt
    FROM {database}.{table_name}
    WHERE {target_column} IS NOT NULL
    GROUP BY {target_column}
)
SELECT
    MAX(cnt) * 1.0 / NULLIF(MIN(cnt), 0) as imbalance_ratio,
    CASE
        WHEN MAX(cnt) * 1.0 / NULLIF(MIN(cnt), 0) <= 3 THEN 'PASS - Balanced'
        WHEN MAX(cnt) * 1.0 / NULLIF(MIN(cnt), 0) <= 10 THEN 'WARNING - Moderate Imbalance'
        ELSE 'FAIL - Severe Imbalance'
    END as balance_status
FROM class_counts;

-- =====================================================
-- 3. FEATURE COMPLETENESS CHECK
-- =====================================================

-- Check for missing values in numeric features
SELECT
    '{numeric_feature_1}' as feature_name,
    'Numeric' as feature_type,
    COUNT(*) as total_rows,
    COUNT({numeric_feature_1}) as non_null_count,
    COUNT(*) - COUNT({numeric_feature_1}) as null_count,
    CAST((COUNT(*) - COUNT({numeric_feature_1})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as null_percentage,
    CASE
        WHEN COUNT({numeric_feature_1}) = COUNT(*) THEN 'PASS'
        WHEN (COUNT(*) - COUNT({numeric_feature_1})) * 100.0 / COUNT(*) < 5 THEN 'WARNING'
        ELSE 'FAIL'
    END as completeness_status
FROM {database}.{table_name}

UNION ALL

-- Check categorical features
SELECT
    '{categorical_feature_1}' as feature_name,
    'Categorical' as feature_type,
    COUNT(*) as total_rows,
    COUNT({categorical_feature_1}) as non_null_count,
    COUNT(*) - COUNT({categorical_feature_1}) as null_count,
    CAST((COUNT(*) - COUNT({categorical_feature_1})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as null_percentage,
    CASE
        WHEN COUNT({categorical_feature_1}) = COUNT(*) THEN 'PASS'
        WHEN (COUNT(*) - COUNT({categorical_feature_1})) * 100.0 / COUNT(*) < 5 THEN 'WARNING'
        ELSE 'FAIL'
    END as completeness_status
FROM {database}.{table_name};

-- =====================================================
-- 4. NUMERIC FEATURE VALIDATION
-- =====================================================

-- Check numeric features for statistical properties
SELECT
    '{numeric_feature_1}' as feature_name,
    COUNT(*) as total_count,
    COUNT({numeric_feature_1}) as non_null_count,
    AVG({numeric_feature_1}) as mean_value,
    STDDEV({numeric_feature_1}) as std_dev,
    MIN({numeric_feature_1}) as min_value,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_feature_1}) as q1,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY {numeric_feature_1}) as median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_feature_1}) as q3,
    MAX({numeric_feature_1}) as max_value,
    CASE
        WHEN STDDEV({numeric_feature_1}) > 0 THEN 'PASS - Has Variance'
        WHEN STDDEV({numeric_feature_1}) = 0 THEN 'FAIL - Constant Value'
        ELSE 'FAIL - All Nulls'
    END as variance_check
FROM {database}.{table_name};

-- Detect outliers using IQR method
WITH stats AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_feature_1}) as q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_feature_1}) as q3
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
    '{numeric_feature_1}' as feature_name,
    COUNT(*) as outlier_count,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name}) AS DECIMAL(5,2)) as outlier_percentage,
    MIN({numeric_feature_1}) as min_outlier_value,
    MAX({numeric_feature_1}) as max_outlier_value,
    CASE
        WHEN COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name}) < 5 THEN 'PASS'
        WHEN COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name}) < 10 THEN 'WARNING'
        ELSE 'FAIL - Too Many Outliers'
    END as outlier_check
FROM {database}.{table_name}, outlier_bounds
WHERE {numeric_feature_1} < lower_bound OR {numeric_feature_1} > upper_bound;

-- =====================================================
-- 5. CATEGORICAL FEATURE VALIDATION
-- =====================================================

-- Check categorical cardinality
SELECT
    '{categorical_feature_1}' as feature_name,
    COUNT(DISTINCT {categorical_feature_1}) as unique_values,
    COUNT(*) as total_records,
    CAST(COUNT(DISTINCT {categorical_feature_1}) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as cardinality_ratio,
    CASE
        WHEN COUNT(DISTINCT {categorical_feature_1}) = 1 THEN 'FAIL - Single Value'
        WHEN COUNT(DISTINCT {categorical_feature_1}) > 50 THEN 'WARNING - High Cardinality'
        WHEN COUNT(DISTINCT {categorical_feature_1}) > 100 THEN 'FAIL - Too Many Categories'
        ELSE 'PASS'
    END as cardinality_check
FROM {database}.{table_name};

-- Categorical value distribution
SELECT
    {categorical_feature_1} as category_value,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    CASE
        WHEN CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) < 1 THEN 'WARNING - Rare Category'
        ELSE 'PASS'
    END as frequency_check
FROM {database}.{table_name}
WHERE {categorical_feature_1} IS NOT NULL
GROUP BY {categorical_feature_1}
ORDER BY count DESC;

-- =====================================================
-- 6. SAMPLE SIZE VALIDATION
-- =====================================================

-- Check if sample size is adequate for naive bayes
WITH sample_stats AS (
    SELECT
        COUNT(*) as total_samples,
        COUNT(DISTINCT {target_column}) as num_classes,
        COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT {target_column}), 0) as samples_per_class
    FROM {database}.{table_name}
    WHERE {target_column} IS NOT NULL
)
SELECT
    total_samples,
    num_classes,
    CAST(samples_per_class AS DECIMAL(10,2)) as avg_samples_per_class,
    CASE
        WHEN total_samples >= 100 AND samples_per_class >= 20 THEN 'PASS - Adequate Sample Size'
        WHEN total_samples >= 50 AND samples_per_class >= 10 THEN 'WARNING - Minimum Sample Size'
        ELSE 'FAIL - Insufficient Sample Size'
    END as sample_adequacy_check
FROM sample_stats;

-- =====================================================
-- 7. DATA CONSISTENCY CHECKS
-- =====================================================

-- Check for duplicate records
SELECT
    {id_column},
    COUNT(*) as duplicate_count
FROM {database}.{table_name}
GROUP BY {id_column}
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- =====================================================
-- 8. COMPREHENSIVE QUALITY SUMMARY
-- =====================================================

SELECT
    'Data Quality Summary' as report_type,
    COUNT(*) as total_records,
    COUNT(DISTINCT {id_column}) as unique_ids,
    COUNT(DISTINCT {target_column}) as num_classes,
    COUNT({target_column}) as non_null_targets,
    CAST((COUNT(*) - COUNT({target_column})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as target_null_pct,
    CASE
        WHEN COUNT(*) >= 100
            AND COUNT(*) = COUNT(DISTINCT {id_column})
            AND COUNT({target_column}) = COUNT(*)
            AND COUNT(DISTINCT {target_column}) >= 2
        THEN 'PASS - Ready for Modeling'
        ELSE 'REVIEW REQUIRED - Check Individual Tests'
    END as overall_quality_status
FROM {database}.{table_name};

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders with actual column names
-- 2. Run each section to identify data quality issues
-- 3. Address FAIL and WARNING statuses before modeling
-- 4. Decision trees are robust to:
--    - Outliers (no need to remove)
--    - Scaling differences (no normalization needed)
--    - Some missing values (handles with surrogate splits)
-- 5. Key concerns for naive bayess:
--    - Class imbalance (use stratified sampling or weights)
--    - High cardinality categoricals (may cause overfitting)
--    - Insufficient samples per class (causes unreliable splits)
--
-- =====================================================
