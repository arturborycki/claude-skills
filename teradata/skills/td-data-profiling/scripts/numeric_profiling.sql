-- =====================================================
-- Numeric Column Profiling - Univariate Statistics
-- =====================================================
-- Purpose: Comprehensive descriptive statistics for numeric columns
-- Uses: TD_UnivariateStatistics, native SQL statistical functions
-- =====================================================

-- =====================================================
-- 1. COMPREHENSIVE UNIVARIATE STATISTICS
-- =====================================================

-- Using TD_UnivariateStatistics for all numeric columns
SELECT * FROM TD_UnivariateStatistics(
    ON {database}.{table_name}
    USING
    TargetColumns({numeric_columns})  -- e.g., 'age', 'income', 'credit_score'
    Stats('COUNT', 'COUNTDISTINCT', 'NULLCOUNT', 'MIN', 'MAX', 'MEAN', 'MEDIAN', 'MODE',
          'STDDEV', 'VARIANCE', 'SKEWNESS', 'KURTOSIS', 'Q1', 'Q3', 'IQR', 'CV', 'RANGE')
    Percentile(1, 5, 10, 25, 50, 75, 90, 95, 99)
) AS dt
ORDER BY column_name
;

-- =====================================================
-- 2. BASIC STATISTICS PER NUMERIC COLUMN
-- =====================================================

-- Alternative native SQL approach for basic statistics
-- Replace {numeric_column} with actual column names

-- Column: {numeric_column_1}
SELECT
    '{numeric_column_1}' as column_name,
    COUNT(*) as total_count,
    COUNT({numeric_column_1}) as non_null_count,
    COUNT(*) - COUNT({numeric_column_1}) as null_count,
    CAST((COUNT(*) - COUNT({numeric_column_1})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as null_percentage,
    COUNT(DISTINCT {numeric_column_1}) as distinct_count,
    CAST(COUNT(DISTINCT {numeric_column_1}) * 100.0 / COUNT({numeric_column_1}) AS DECIMAL(5,2)) as uniqueness_percentage,
    MIN({numeric_column_1}) as minimum,
    MAX({numeric_column_1}) as maximum,
    MAX({numeric_column_1}) - MIN({numeric_column_1}) as range_value,
    AVG({numeric_column_1}) as mean_value,
    STDDEV({numeric_column_1}) as std_deviation,
    VARIANCE({numeric_column_1}) as variance_value,
    CASE
        WHEN AVG({numeric_column_1}) = 0 THEN NULL
        ELSE STDDEV({numeric_column_1}) / NULLIF(AVG({numeric_column_1}), 0) * 100
    END as coefficient_of_variation
FROM {database}.{table_name}
;

-- =====================================================
-- 3. QUARTILES AND PERCENTILES
-- =====================================================

-- Calculate quartiles and percentiles for {numeric_column}
SELECT
    '{numeric_column_1}' as column_name,
    PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY {numeric_column_1}) as p01,
    PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY {numeric_column_1}) as p05,
    PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY {numeric_column_1}) as p10,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_column_1}) as q1_p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY {numeric_column_1}) as median_p50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_column_1}) as q3_p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY {numeric_column_1}) as p90,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY {numeric_column_1}) as p95,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY {numeric_column_1}) as p99,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_column_1}) -
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_column_1}) as iqr
FROM {database}.{table_name}
WHERE {numeric_column_1} IS NOT NULL
;

-- =====================================================
-- 4. DISTRIBUTION SHAPE INDICATORS
-- =====================================================

-- Skewness and Kurtosis calculation (if not using TD_UnivariateStatistics)
WITH stats AS (
    SELECT
        AVG({numeric_column_1}) as mean_val,
        STDDEV({numeric_column_1}) as std_val,
        COUNT(*) as n
    FROM {database}.{table_name}
    WHERE {numeric_column_1} IS NOT NULL
),
moments AS (
    SELECT
        AVG(POWER(({numeric_column_1} - s.mean_val) / NULLIF(s.std_val, 0), 3)) as skewness_raw,
        AVG(POWER(({numeric_column_1} - s.mean_val) / NULLIF(s.std_val, 0), 4)) as kurtosis_raw
    FROM {database}.{table_name} t, stats s
    WHERE t.{numeric_column_1} IS NOT NULL
)
SELECT
    '{numeric_column_1}' as column_name,
    skewness_raw as skewness,
    kurtosis_raw - 3 as excess_kurtosis,
    CASE
        WHEN ABS(skewness_raw) < 0.5 THEN 'Approximately Symmetric'
        WHEN skewness_raw > 0.5 THEN 'Right-skewed (Positive skew)'
        WHEN skewness_raw < -0.5 THEN 'Left-skewed (Negative skew)'
    END as skewness_interpretation,
    CASE
        WHEN ABS(kurtosis_raw - 3) < 0.5 THEN 'Normal (Mesokurtic)'
        WHEN kurtosis_raw - 3 > 0.5 THEN 'Heavy-tailed (Leptokurtic)'
        WHEN kurtosis_raw - 3 < -0.5 THEN 'Light-tailed (Platykurtic)'
    END as kurtosis_interpretation
FROM moments
;

-- =====================================================
-- 5. DATA COMPLETENESS AND QUALITY
-- =====================================================

-- Comprehensive quality assessment per numeric column
SELECT
    '{numeric_column_1}' as column_name,
    COUNT(*) as total_records,
    COUNT({numeric_column_1}) as non_null_count,
    COUNT(*) - COUNT({numeric_column_1}) as null_count,
    CAST((COUNT(*) - COUNT({numeric_column_1})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as null_percentage,
    COUNT(DISTINCT {numeric_column_1}) as distinct_values,
    CASE
        WHEN COUNT(DISTINCT {numeric_column_1}) = 1 THEN 'FAIL - Single Value (No Variance)'
        WHEN COUNT(DISTINCT {numeric_column_1}) * 100.0 / COUNT({numeric_column_1}) < 1 THEN 'WARNING - Very Low Variance'
        ELSE 'PASS - Adequate Variance'
    END as variance_check,
    CASE
        WHEN (COUNT(*) - COUNT({numeric_column_1})) * 100.0 / COUNT(*) = 0 THEN 100
        WHEN (COUNT(*) - COUNT({numeric_column_1})) * 100.0 / COUNT(*) <= 5 THEN 95
        WHEN (COUNT(*) - COUNT({numeric_column_1})) * 100.0 / COUNT(*) <= 10 THEN 85
        WHEN (COUNT(*) - COUNT({numeric_column_1})) * 100.0 / COUNT(*) <= 20 THEN 70
        ELSE 50
    END as completeness_score
FROM {database}.{table_name}
;

-- =====================================================
-- 6. VALUE DISTRIBUTION SUMMARY
-- =====================================================

-- Top 10 most frequent values for numeric column
SELECT
    {numeric_column_1} as value,
    COUNT(*) as frequency,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    CAST(SUM(COUNT(*)) OVER(ORDER BY COUNT(*) DESC, {numeric_column_1}
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) * 100.0 /
         SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as cumulative_percentage
FROM {database}.{table_name}
WHERE {numeric_column_1} IS NOT NULL
GROUP BY {numeric_column_1}
ORDER BY frequency DESC, {numeric_column_1}
FETCH FIRST 10 ROWS ONLY
;

-- =====================================================
-- 7. ZERO AND NEGATIVE VALUE ANALYSIS
-- =====================================================

-- Analyze special numeric values
SELECT
    '{numeric_column_1}' as column_name,
    SUM(CASE WHEN {numeric_column_1} = 0 THEN 1 ELSE 0 END) as zero_count,
    CAST(SUM(CASE WHEN {numeric_column_1} = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as zero_percentage,
    SUM(CASE WHEN {numeric_column_1} < 0 THEN 1 ELSE 0 END) as negative_count,
    CAST(SUM(CASE WHEN {numeric_column_1} < 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as negative_percentage,
    SUM(CASE WHEN {numeric_column_1} > 0 THEN 1 ELSE 0 END) as positive_count,
    CAST(SUM(CASE WHEN {numeric_column_1} > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as positive_percentage
FROM {database}.{table_name}
;

-- =====================================================
-- 8. NUMERIC PROFILING CONSOLIDATED REPORT
-- =====================================================

-- Single comprehensive query for numeric column profile
-- Create table to store results
CREATE MULTISET TABLE {database}.{table_name}_numeric_profile AS (
    WITH basic_stats AS (
        SELECT
            '{numeric_column_1}' as column_name,
            'NUMERIC' as data_type,
            COUNT(*) as total_count,
            COUNT({numeric_column_1}) as non_null_count,
            COUNT(*) - COUNT({numeric_column_1}) as null_count,
            COUNT(DISTINCT {numeric_column_1}) as distinct_count,
            MIN({numeric_column_1}) as min_value,
            MAX({numeric_column_1}) as max_value,
            AVG({numeric_column_1}) as mean_value,
            STDDEV({numeric_column_1}) as std_dev,
            VARIANCE({numeric_column_1}) as variance_value
        FROM {database}.{table_name}
    ),
    quartile_stats AS (
        SELECT
            PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_column_1}) as q1,
            PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY {numeric_column_1}) as median,
            PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_column_1}) as q3
        FROM {database}.{table_name}
        WHERE {numeric_column_1} IS NOT NULL
    )
    SELECT
        b.column_name,
        b.data_type,
        b.total_count,
        b.non_null_count,
        b.null_count,
        CAST(b.null_count * 100.0 / b.total_count AS DECIMAL(5,2)) as null_percentage,
        b.distinct_count,
        CAST(b.distinct_count * 100.0 / b.non_null_count AS DECIMAL(5,2)) as uniqueness_percentage,
        b.min_value,
        q.q1,
        q.median,
        b.mean_value,
        q.q3,
        b.max_value,
        b.std_dev,
        b.variance_value,
        q.q3 - q.q1 as iqr,
        CASE
            WHEN b.mean_value = 0 THEN NULL
            ELSE b.std_dev / NULLIF(b.mean_value, 0) * 100
        END as coefficient_of_variation,
        CURRENT_TIMESTAMP as profiled_at
    FROM basic_stats b, quartile_stats q
) WITH DATA PRIMARY INDEX (column_name)
;

-- View the profile
SELECT * FROM {database}.{table_name}_numeric_profile;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {table_name} - Your table name
--    {numeric_columns} - Comma-separated list of numeric columns for TD_UnivariateStatistics
--    {numeric_column_1}, {numeric_column_2}, etc. - Individual numeric column names
--
-- 2. Execute Section 1 for automated comprehensive statistics using TD_ functions
--    OR execute Sections 2-7 for detailed native SQL analysis
--
-- 3. Execute Section 8 to create a consolidated profile table
--
-- 4. Repeat for all numeric columns in your table
--
-- 5. Analyze results for:
--    - Central tendency (mean, median)
--    - Dispersion (std dev, variance, IQR)
--    - Distribution shape (skewness, kurtosis)
--    - Data quality (completeness, variance)
--
-- =====================================================
