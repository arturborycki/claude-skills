-- =====================================================
-- Categorical Column Profiling - Frequency Analysis
-- =====================================================
-- Purpose: Comprehensive frequency and distribution analysis for categorical columns
-- Uses: TD_Frequency, native SQL aggregation functions
-- =====================================================

-- =====================================================
-- 1. TD_FREQUENCY ANALYSIS
-- =====================================================

-- Using TD_Frequency for categorical columns
SELECT * FROM TD_Frequency(
    ON {database}.{table_name}
    USING
    TargetColumns({categorical_columns})  -- e.g., 'customer_segment', 'region', 'product_category'
    TopK(10)  -- Top 10 most frequent values
    OthersCategoryName('Other_Values')
) AS dt
ORDER BY column_name, frequency DESC
;

-- =====================================================
-- 2. BASIC CATEGORICAL STATISTICS
-- =====================================================

-- Cardinality and completeness for {categorical_column}
SELECT
    '{categorical_column}' as column_name,
    'CATEGORICAL' as data_type,
    COUNT(*) as total_count,
    COUNT({categorical_column}) as non_null_count,
    COUNT(*) - COUNT({categorical_column}) as null_count,
    CAST((COUNT(*) - COUNT({categorical_column})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as null_percentage,
    COUNT(DISTINCT {categorical_column}) as distinct_count,
    CAST(COUNT(DISTINCT {categorical_column}) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as cardinality_ratio,
    CASE
        WHEN COUNT(DISTINCT {categorical_column}) = 1 THEN 'FAIL - Single Value'
        WHEN COUNT(DISTINCT {categorical_column}) > 100 THEN 'WARNING - Very High Cardinality'
        WHEN COUNT(DISTINCT {categorical_column}) > 50 THEN 'WARNING - High Cardinality'
        ELSE 'PASS - Normal Cardinality'
    END as cardinality_assessment
FROM {database}.{table_name}
;

-- =====================================================
-- 3. VALUE FREQUENCY DISTRIBUTION
-- =====================================================

-- Complete frequency distribution for {categorical_column}
SELECT
    '{categorical_column}' as column_name,
    {categorical_column} as category_value,
    COUNT(*) as frequency,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    CAST(SUM(COUNT(*)) OVER(ORDER BY COUNT(*) DESC, {categorical_column}
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) * 100.0 /
         SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as cumulative_percentage,
    RANK() OVER(ORDER BY COUNT(*) DESC) as frequency_rank
FROM {database}.{table_name}
WHERE {categorical_column} IS NOT NULL
GROUP BY {categorical_column}
ORDER BY frequency DESC, {categorical_column}
;

-- =====================================================
-- 4. TOP K MOST FREQUENT VALUES
-- =====================================================

-- Top 10 most frequent categories
SELECT
    '{categorical_column}' as column_name,
    {categorical_column} as category_value,
    COUNT(*) as frequency,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {database}.{table_name}
WHERE {categorical_column} IS NOT NULL
GROUP BY {categorical_column}
ORDER BY frequency DESC
FETCH FIRST 10 ROWS ONLY
;

-- =====================================================
-- 5. RARE VALUES DETECTION
-- =====================================================

-- Identify rare categories (frequency < 1% of total)
WITH value_counts AS (
    SELECT
        {categorical_column} as category_value,
        COUNT(*) as frequency,
        CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
    FROM {database}.{table_name}
    WHERE {categorical_column} IS NOT NULL
    GROUP BY {categorical_column}
)
SELECT
    '{categorical_column}' as column_name,
    COUNT(*) as rare_value_count,
    SUM(frequency) as total_rare_frequency,
    CAST(SUM(frequency) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name}) AS DECIMAL(5,2)) as rare_value_percentage,
    LISTAGG(category_value, ', ') WITHIN GROUP (ORDER BY frequency) as rare_values
FROM value_counts
WHERE percentage < 1.0
;

-- =====================================================
-- 6. DISTRIBUTION BALANCE ANALYSIS
-- =====================================================

-- Analyze distribution uniformity
WITH value_stats AS (
    SELECT
        {categorical_column} as category_value,
        COUNT(*) as frequency
    FROM {database}.{table_name}
    WHERE {categorical_column} IS NOT NULL
    GROUP BY {categorical_column}
),
distribution_metrics AS (
    SELECT
        COUNT(*) as num_categories,
        AVG(frequency) as avg_frequency,
        STDDEV(frequency) as std_frequency,
        MIN(frequency) as min_frequency,
        MAX(frequency) as max_frequency
    FROM value_stats
)
SELECT
    '{categorical_column}' as column_name,
    num_categories,
    avg_frequency,
    std_frequency,
    min_frequency,
    max_frequency,
    CAST(max_frequency * 1.0 / NULLIF(min_frequency, 0) AS DECIMAL(10,2)) as imbalance_ratio,
    CASE
        WHEN STDDEV(frequency) / NULLIF(AVG(frequency), 0) < 0.3 THEN 'Highly Balanced'
        WHEN STDDEV(frequency) / NULLIF(AVG(frequency), 0) < 0.7 THEN 'Moderately Balanced'
        ELSE 'Imbalanced'
    END as distribution_balance,
    CASE
        WHEN max_frequency * 1.0 / NULLIF(min_frequency, 0) < 3 THEN 'PASS - Well Balanced'
        WHEN max_frequency * 1.0 / NULLIF(min_frequency, 0) < 10 THEN 'WARNING - Moderate Imbalance'
        ELSE 'FAIL - Severe Imbalance'
    END as balance_check
FROM distribution_metrics, value_stats
GROUP BY num_categories, avg_frequency, std_frequency, min_frequency, max_frequency
;

-- =====================================================
-- 7. MODE DETECTION
-- =====================================================

-- Find the mode (most frequent value)
WITH value_counts AS (
    SELECT
        {categorical_column} as category_value,
        COUNT(*) as frequency
    FROM {database}.{table_name}
    WHERE {categorical_column} IS NOT NULL
    GROUP BY {categorical_column}
),
max_frequency AS (
    SELECT MAX(frequency) as max_freq
    FROM value_counts
)
SELECT
    '{categorical_column}' as column_name,
    vc.category_value as mode_value,
    vc.frequency as mode_frequency,
    CAST(vc.frequency * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name}) AS DECIMAL(5,2)) as mode_percentage
FROM value_counts vc, max_frequency mf
WHERE vc.frequency = mf.max_freq
ORDER BY vc.category_value
;

-- =====================================================
-- 8. ENTROPY CALCULATION
-- =====================================================

-- Calculate Shannon entropy (measure of information content)
WITH value_probabilities AS (
    SELECT
        {categorical_column} as category_value,
        COUNT(*) as frequency,
        CAST(COUNT(*) * 1.0 / SUM(COUNT(*)) OVER() AS FLOAT) as probability
    FROM {database}.{table_name}
    WHERE {categorical_column} IS NOT NULL
    GROUP BY {categorical_column}
)
SELECT
    '{categorical_column}' as column_name,
    -SUM(probability * LOG(2, probability)) as entropy,
    LOG(2, COUNT(DISTINCT category_value)) as max_entropy,
    -SUM(probability * LOG(2, probability)) / NULLIF(LOG(2, COUNT(DISTINCT category_value)), 0) as normalized_entropy,
    CASE
        WHEN -SUM(probability * LOG(2, probability)) / NULLIF(LOG(2, COUNT(DISTINCT category_value)), 0) > 0.9
            THEN 'High Entropy - Nearly Uniform Distribution'
        WHEN -SUM(probability * LOG(2, probability)) / NULLIF(LOG(2, COUNT(DISTINCT category_value)), 0) > 0.6
            THEN 'Moderate Entropy - Reasonably Distributed'
        ELSE 'Low Entropy - Concentrated Distribution'
    END as entropy_interpretation
FROM value_probabilities
;

-- =====================================================
-- 9. NULL VALUE ANALYSIS
-- =====================================================

-- Detailed null value assessment
SELECT
    '{categorical_column}' as column_name,
    COUNT(*) as total_records,
    COUNT({categorical_column}) as non_null_count,
    COUNT(*) - COUNT({categorical_column}) as null_count,
    CAST((COUNT(*) - COUNT({categorical_column})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as null_percentage,
    CASE
        WHEN COUNT({categorical_column}) = COUNT(*) THEN 'PASS - No Missing Values'
        WHEN (COUNT(*) - COUNT({categorical_column})) * 100.0 / COUNT(*) < 5 THEN 'WARNING - < 5% Missing'
        WHEN (COUNT(*) - COUNT({categorical_column})) * 100.0 / COUNT(*) < 20 THEN 'WARNING - 5-20% Missing'
        ELSE 'FAIL - > 20% Missing'
    END as completeness_check,
    CASE
        WHEN (COUNT(*) - COUNT({categorical_column})) * 100.0 / COUNT(*) = 0 THEN 100
        WHEN (COUNT(*) - COUNT({categorical_column})) * 100.0 / COUNT(*) <= 5 THEN 95
        WHEN (COUNT(*) - COUNT({categorical_column})) * 100.0 / COUNT(*) <= 10 THEN 85
        WHEN (COUNT(*) - COUNT({categorical_column})) * 100.0 / COUNT(*) <= 20 THEN 70
        ELSE 50
    END as completeness_score
FROM {database}.{table_name}
;

-- =====================================================
-- 10. CATEGORICAL PROFILING CONSOLIDATED REPORT
-- =====================================================

-- Create comprehensive profile table for categorical columns
CREATE MULTISET TABLE {database}.{table_name}_categorical_profile AS (
    WITH basic_stats AS (
        SELECT
            '{categorical_column}' as column_name,
            'CATEGORICAL' as data_type,
            COUNT(*) as total_count,
            COUNT({categorical_column}) as non_null_count,
            COUNT(*) - COUNT({categorical_column}) as null_count,
            COUNT(DISTINCT {categorical_column}) as distinct_count
        FROM {database}.{table_name}
    ),
    mode_calc AS (
        SELECT
            {categorical_column} as mode_value,
            COUNT(*) as mode_frequency
        FROM {database}.{table_name}
        WHERE {categorical_column} IS NOT NULL
        GROUP BY {categorical_column}
        QUALIFY ROW_NUMBER() OVER(ORDER BY COUNT(*) DESC) = 1
    ),
    distribution_stats AS (
        SELECT
            STDDEV(cnt) as freq_std_dev,
            AVG(cnt) as freq_avg,
            MIN(cnt) as freq_min,
            MAX(cnt) as freq_max
        FROM (
            SELECT COUNT(*) as cnt
            FROM {database}.{table_name}
            WHERE {categorical_column} IS NOT NULL
            GROUP BY {categorical_column}
        ) AS freq_dist
    )
    SELECT
        b.column_name,
        b.data_type,
        b.total_count,
        b.non_null_count,
        b.null_count,
        CAST(b.null_count * 100.0 / b.total_count AS DECIMAL(5,2)) as null_percentage,
        b.distinct_count,
        CAST(b.distinct_count * 100.0 / b.non_null_count AS DECIMAL(5,2)) as cardinality_ratio,
        m.mode_value,
        m.mode_frequency,
        CAST(m.mode_frequency * 100.0 / b.non_null_count AS DECIMAL(5,2)) as mode_percentage,
        d.freq_min as min_frequency,
        d.freq_max as max_frequency,
        d.freq_avg as avg_frequency,
        d.freq_std_dev as std_frequency,
        CAST(d.freq_max * 1.0 / NULLIF(d.freq_min, 0) AS DECIMAL(10,2)) as imbalance_ratio,
        CURRENT_TIMESTAMP as profiled_at
    FROM basic_stats b, mode_calc m, distribution_stats d
) WITH DATA PRIMARY INDEX (column_name)
;

-- View the profile
SELECT * FROM {database}.{table_name}_categorical_profile;

-- =====================================================
-- 11. VALUE LENGTH ANALYSIS (for VARCHAR columns)
-- =====================================================

-- Analyze string length distribution
SELECT
    '{categorical_column}' as column_name,
    MIN(CHARACTER_LENGTH({categorical_column})) as min_length,
    MAX(CHARACTER_LENGTH({categorical_column})) as max_length,
    AVG(CHARACTER_LENGTH({categorical_column})) as avg_length,
    STDDEV(CHARACTER_LENGTH({categorical_column})) as std_length,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CHARACTER_LENGTH({categorical_column})) as median_length
FROM {database}.{table_name}
WHERE {categorical_column} IS NOT NULL
;

-- =====================================================
-- 12. PATTERN DETECTION (Basic)
-- =====================================================

-- Check for common patterns in categorical values
SELECT
    '{categorical_column}' as column_name,
    SUM(CASE WHEN REGEXP_SIMILAR({categorical_column}, '[0-9]+', 'i') = 1 THEN 1 ELSE 0 END) as numeric_pattern_count,
    SUM(CASE WHEN REGEXP_SIMILAR({categorical_column}, '[A-Z]+', 'i') = 1 THEN 1 ELSE 0 END) as alphabetic_pattern_count,
    SUM(CASE WHEN REGEXP_SIMILAR({categorical_column}, '[A-Z0-9]+', 'i') = 1 THEN 1 ELSE 0 END) as alphanumeric_pattern_count,
    SUM(CASE WHEN TRIM({categorical_column}) <> {categorical_column} THEN 1 ELSE 0 END) as whitespace_issue_count
FROM {database}.{table_name}
WHERE {categorical_column} IS NOT NULL
;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {table_name} - Your table name
--    {categorical_columns} - Comma-separated list for TD_Frequency
--    {categorical_column} - Individual categorical column name
--
-- 2. Execute Section 1 for automated frequency analysis using TD_Frequency
--    OR execute Sections 2-9 for detailed native SQL analysis
--
-- 3. Execute Section 10 to create consolidated profile table
--
-- 4. Analyze results for:
--    - Cardinality (distinct value count)
--    - Distribution balance
--    - Rare values requiring special handling
--    - Most frequent values (mode)
--    - Data completeness
--
-- =====================================================
