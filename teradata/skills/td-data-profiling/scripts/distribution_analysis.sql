-- =====================================================
-- Distribution Analysis - Histograms and Shape
-- =====================================================
-- Purpose: Analyze data distributions using histogram and shape metrics
-- Uses: TD_Histogram, statistical distribution analysis
-- =====================================================

-- =====================================================
-- 1. HISTOGRAM GENERATION USING TD_HISTOGRAM
-- =====================================================

-- Create histogram for numeric column using TD_Histogram
SELECT * FROM TD_Histogram(
    ON {database}.{table_name}
    USING
    TargetColumn('{numeric_column}')
    NumBins(20)  -- Number of bins for histogram
    BinStyle('equal-width')  -- or 'equal-frequency'
) AS dt
ORDER BY bin_id
;

-- =====================================================
-- 2. CUSTOM HISTOGRAM WITH EQUAL-WIDTH BINS
-- =====================================================

-- Manual histogram creation for {numeric_column}
WITH min_max AS (
    SELECT
        MIN({numeric_column}) as min_val,
        MAX({numeric_column}) as max_val,
        20 as num_bins  -- Configurable bin count
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
),
bin_config AS (
    SELECT
        min_val,
        max_val,
        num_bins,
        (max_val - min_val) / num_bins as bin_width
    FROM min_max
),
binned_data AS (
    SELECT
        {numeric_column},
        CASE
            WHEN {numeric_column} = (SELECT max_val FROM bin_config)
            THEN (SELECT num_bins FROM bin_config) - 1
            ELSE FLOOR(({numeric_column} - (SELECT min_val FROM bin_config)) /
                      NULLIF((SELECT bin_width FROM bin_config), 0))
        END as bin_id
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
)
SELECT
    '{numeric_column}' as column_name,
    bd.bin_id,
    bc.min_val + (bd.bin_id * bc.bin_width) as bin_lower_bound,
    bc.min_val + ((bd.bin_id + 1) * bc.bin_width) as bin_upper_bound,
    COUNT(*) as frequency,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    RPAD('*', CAST(COUNT(*) * 50.0 / MAX(COUNT(*)) OVER() AS INTEGER), '*') as visual_bar
FROM binned_data bd, bin_config bc
GROUP BY bd.bin_id, bc.min_val, bc.bin_width
ORDER BY bd.bin_id
;

-- =====================================================
-- 3. HISTOGRAM WITH EQUAL-FREQUENCY BINS
-- =====================================================

-- Equal-frequency binning (quantile-based)
WITH ranked_data AS (
    SELECT
        {numeric_column},
        NTILE(20) OVER (ORDER BY {numeric_column}) as bin_id  -- 20 equal-frequency bins
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
)
SELECT
    '{numeric_column}' as column_name,
    bin_id,
    MIN({numeric_column}) as bin_lower_bound,
    MAX({numeric_column}) as bin_upper_bound,
    COUNT(*) as frequency,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    AVG({numeric_column}) as bin_mean
FROM ranked_data
GROUP BY bin_id
ORDER BY bin_id
;

-- =====================================================
-- 4. DISTRIBUTION TYPE DETECTION
-- =====================================================

-- Analyze distribution characteristics
WITH stats AS (
    SELECT
        COUNT(*) as n,
        AVG({numeric_column}) as mean_val,
        STDDEV({numeric_column}) as std_val,
        MIN({numeric_column}) as min_val,
        MAX({numeric_column}) as max_val
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
),
quartiles AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_column}) as q1,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY {numeric_column}) as median,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_column}) as q3
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
),
shape_metrics AS (
    SELECT
        AVG(POWER(({numeric_column} - s.mean_val) / NULLIF(s.std_val, 0), 3)) as skewness,
        AVG(POWER(({numeric_column} - s.mean_val) / NULLIF(s.std_val, 0), 4)) - 3 as excess_kurtosis
    FROM {database}.{table_name} t, stats s
    WHERE t.{numeric_column} IS NOT NULL
)
SELECT
    '{numeric_column}' as column_name,
    s.n as sample_size,
    s.mean_val as mean,
    q.median,
    s.std_val as std_dev,
    sm.skewness,
    sm.excess_kurtosis,
    -- Mean vs Median relationship
    CASE
        WHEN ABS(s.mean_val - q.median) / NULLIF(s.std_val, 0) < 0.1 THEN 'Symmetric'
        WHEN s.mean_val > q.median THEN 'Right-skewed'
        ELSE 'Left-skewed'
    END as mean_median_indication,
    -- Skewness interpretation
    CASE
        WHEN ABS(sm.skewness) < 0.5 THEN 'Approximately Symmetric'
        WHEN sm.skewness > 0.5 THEN 'Right-skewed (long tail right)'
        ELSE 'Left-skewed (long tail left)'
    END as skewness_interpretation,
    -- Kurtosis interpretation
    CASE
        WHEN ABS(sm.excess_kurtosis) < 0.5 THEN 'Normal tails (Mesokurtic)'
        WHEN sm.excess_kurtosis > 0.5 THEN 'Heavy tails (Leptokurtic)'
        ELSE 'Light tails (Platykurtic)'
    END as kurtosis_interpretation,
    -- Distribution type suggestion
    CASE
        WHEN ABS(sm.skewness) < 0.5 AND ABS(sm.excess_kurtosis) < 0.5 THEN 'Potentially Normal'
        WHEN sm.skewness > 1 AND s.min_val >= 0 THEN 'Possibly Log-normal or Exponential'
        WHEN ABS(sm.excess_kurtosis) > 3 THEN 'Heavy-tailed (consider outlier analysis)'
        WHEN s.min_val >= 0 AND s.max_val <= 1 THEN 'Possibly Beta or Uniform'
        ELSE 'Non-standard distribution'
    END as distribution_type_suggestion
FROM stats s, quartiles q, shape_metrics sm
;

-- =====================================================
-- 5. NORMALITY ASSESSMENT
-- =====================================================

-- Check indicators of normality
WITH stats AS (
    SELECT
        AVG({numeric_column}) as mean_val,
        STDDEV({numeric_column}) as std_val
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
),
empirical_rule AS (
    SELECT
        SUM(CASE WHEN ABS({numeric_column} - s.mean_val) <= s.std_val THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as pct_within_1sd,
        SUM(CASE WHEN ABS({numeric_column} - s.mean_val) <= 2 * s.std_val THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as pct_within_2sd,
        SUM(CASE WHEN ABS({numeric_column} - s.mean_val) <= 3 * s.std_val THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as pct_within_3sd
    FROM {database}.{table_name} t, stats s
    WHERE t.{numeric_column} IS NOT NULL
)
SELECT
    '{numeric_column}' as column_name,
    CAST(pct_within_1sd AS DECIMAL(5,2)) as pct_within_1_std_dev,
    CAST(pct_within_2sd AS DECIMAL(5,2)) as pct_within_2_std_dev,
    CAST(pct_within_3sd AS DECIMAL(5,2)) as pct_within_3_std_dev,
    -- Expected values for normal distribution: 68%, 95%, 99.7%
    CASE
        WHEN pct_within_1sd BETWEEN 63 AND 73
         AND pct_within_2sd BETWEEN 90 AND 98
         AND pct_within_3sd > 99
        THEN 'Consistent with Normal Distribution'
        ELSE 'Likely Non-Normal Distribution'
    END as empirical_rule_assessment
FROM empirical_rule
;

-- =====================================================
-- 6. BIMODALITY DETECTION
-- =====================================================

-- Check for potential bimodal distribution
WITH histogram AS (
    SELECT
        NTILE(20) OVER (ORDER BY {numeric_column}) as bin_id,
        {numeric_column}
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
),
bin_counts AS (
    SELECT
        bin_id,
        COUNT(*) as frequency
    FROM histogram
    GROUP BY bin_id
),
peaks_valleys AS (
    SELECT
        bin_id,
        frequency,
        LAG(frequency, 1) OVER (ORDER BY bin_id) as prev_freq,
        LEAD(frequency, 1) OVER (ORDER BY bin_id) as next_freq
    FROM bin_counts
),
local_maxima AS (
    SELECT
        COUNT(*) as num_peaks
    FROM peaks_valleys
    WHERE frequency > COALESCE(prev_freq, 0)
      AND frequency > COALESCE(next_freq, 0)
)
SELECT
    '{numeric_column}' as column_name,
    num_peaks,
    CASE
        WHEN num_peaks = 1 THEN 'Unimodal (single peak)'
        WHEN num_peaks = 2 THEN 'Potentially Bimodal (two peaks)'
        WHEN num_peaks > 2 THEN 'Multimodal (multiple peaks)'
        ELSE 'Uniform or unclear distribution'
    END as modality_assessment
FROM local_maxima
;

-- =====================================================
-- 7. CONCENTRATION ANALYSIS
-- =====================================================

-- Analyze where data is concentrated
WITH value_counts AS (
    SELECT
        {numeric_column},
        COUNT(*) as frequency
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
    GROUP BY {numeric_column}
),
ranked_values AS (
    SELECT
        {numeric_column},
        frequency,
        SUM(frequency) OVER(ORDER BY frequency DESC, {numeric_column}
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as cumulative_freq,
        SUM(frequency) OVER() as total_freq
    FROM value_counts
)
SELECT
    '{numeric_column}' as column_name,
    MIN(CASE WHEN cumulative_freq * 100.0 / total_freq <= 50 THEN {numeric_column} END) as min_value_top50pct,
    MAX(CASE WHEN cumulative_freq * 100.0 / total_freq <= 50 THEN {numeric_column} END) as max_value_top50pct,
    COUNT(DISTINCT CASE WHEN cumulative_freq * 100.0 / total_freq <= 50 THEN {numeric_column} END) as distinct_values_top50pct,
    COUNT(DISTINCT CASE WHEN cumulative_freq * 100.0 / total_freq <= 80 THEN {numeric_column} END) as distinct_values_top80pct,
    COUNT(DISTINCT {numeric_column}) as total_distinct_values
FROM ranked_values
;

-- =====================================================
-- 8. BOX PLOT STATISTICS
-- =====================================================

-- Generate box plot summary statistics
WITH quartiles AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_column}) as q1,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY {numeric_column}) as median,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_column}) as q3
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
),
iqr_calc AS (
    SELECT
        q1,
        median,
        q3,
        q3 - q1 as iqr,
        q1 - 1.5 * (q3 - q1) as lower_fence,
        q3 + 1.5 * (q3 - q1) as upper_fence
    FROM quartiles
),
outlier_bounds AS (
    SELECT
        MIN(CASE WHEN {numeric_column} >= lower_fence THEN {numeric_column} END) as lower_whisker,
        MAX(CASE WHEN {numeric_column} <= upper_fence THEN {numeric_column} END) as upper_whisker
    FROM {database}.{table_name}, iqr_calc
    WHERE {numeric_column} IS NOT NULL
)
SELECT
    '{numeric_column}' as column_name,
    i.q1,
    i.median,
    i.q3,
    i.iqr,
    i.lower_fence,
    i.upper_fence,
    o.lower_whisker,
    o.upper_whisker,
    (SELECT COUNT(*) FROM {database}.{table_name} WHERE {numeric_column} < i.lower_fence) as lower_outlier_count,
    (SELECT COUNT(*) FROM {database}.{table_name} WHERE {numeric_column} > i.upper_fence) as upper_outlier_count
FROM iqr_calc i, outlier_bounds o
;

-- =====================================================
-- 9. DISTRIBUTION SUMMARY TABLE
-- =====================================================

-- Create consolidated distribution profile
CREATE MULTISET TABLE {database}.{table_name}_distribution_profile AS (
    WITH stats AS (
        SELECT
            AVG({numeric_column}) as mean_val,
            STDDEV({numeric_column}) as std_val,
            MIN({numeric_column}) as min_val,
            MAX({numeric_column}) as max_val,
            COUNT(*) as n
        FROM {database}.{table_name}
        WHERE {numeric_column} IS NOT NULL
    ),
    quartiles AS (
        SELECT
            PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_column}) as q1,
            PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY {numeric_column}) as median,
            PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_column}) as q3
        FROM {database}.{table_name}
        WHERE {numeric_column} IS NOT NULL
    ),
    shape AS (
        SELECT
            AVG(POWER(({numeric_column} - s.mean_val) / NULLIF(s.std_val, 0), 3)) as skewness,
            AVG(POWER(({numeric_column} - s.mean_val) / NULLIF(s.std_val, 0), 4)) - 3 as kurtosis
        FROM {database}.{table_name} t, stats s
        WHERE t.{numeric_column} IS NOT NULL
    )
    SELECT
        '{numeric_column}' as column_name,
        s.n as sample_size,
        s.min_val,
        q.q1,
        q.median,
        s.mean_val as mean,
        q.q3,
        s.max_val,
        s.std_val as std_dev,
        q.q3 - q.q1 as iqr,
        sh.skewness,
        sh.kurtosis,
        CASE
            WHEN ABS(sh.skewness) < 0.5 THEN 'Approximately Symmetric'
            WHEN sh.skewness > 0.5 THEN 'Right-skewed'
            ELSE 'Left-skewed'
        END as distribution_shape,
        CURRENT_TIMESTAMP as profiled_at
    FROM stats s, quartiles q, shape sh
) WITH DATA PRIMARY INDEX (column_name)
;

-- View the profile
SELECT * FROM {database}.{table_name}_distribution_profile;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {table_name} - Your table name
--    {numeric_column} - Numeric column name to analyze
--
-- 2. Execute Section 1 for TD_Histogram automated analysis
--    OR Sections 2-3 for custom histogram creation
--
-- 3. Execute Sections 4-8 for comprehensive distribution analysis
--
-- 4. Execute Section 9 to create consolidated distribution profile
--
-- 5. Analyze results for:
--    - Distribution shape (symmetric, skewed)
--    - Tail behavior (normal, heavy, light)
--    - Potential distribution family
--    - Data concentration patterns
--    - Outlier boundaries
--
-- =====================================================
