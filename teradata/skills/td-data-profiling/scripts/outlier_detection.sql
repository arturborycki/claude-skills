-- =====================================================
-- Outlier Detection and Analysis
-- =====================================================
-- Purpose: Identify outliers using multiple statistical methods
-- Methods: IQR, Z-score, Modified Z-score, Percentile-based
-- =====================================================

-- =====================================================
-- 1. IQR METHOD (Interquartile Range)
-- =====================================================

-- Detect outliers using IQR method (most common)
WITH quartiles AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_column}) as q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_column}) as q3
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
),
outlier_bounds AS (
    SELECT
        q1,
        q3,
        q3 - q1 as iqr,
        q1 - 1.5 * (q3 - q1) as lower_bound,
        q3 + 1.5 * (q3 - q1) as upper_bound,
        q1 - 3.0 * (q3 - q1) as extreme_lower_bound,
        q3 + 3.0 * (q3 - q1) as extreme_upper_bound
    FROM quartiles
)
SELECT
    '{numeric_column}' as column_name,
    'IQR Method' as detection_method,
    ob.q1,
    ob.q3,
    ob.iqr,
    CAST(ob.lower_bound AS DECIMAL(15,4)) as lower_outlier_threshold,
    CAST(ob.upper_bound AS DECIMAL(15,4)) as upper_outlier_threshold,
    CAST(ob.extreme_lower_bound AS DECIMAL(15,4)) as extreme_lower_threshold,
    CAST(ob.extreme_upper_bound AS DECIMAL(15,4)) as extreme_upper_threshold,
    COUNT(*) as total_records,
    SUM(CASE WHEN {numeric_column} < ob.lower_bound OR {numeric_column} > ob.upper_bound THEN 1 ELSE 0 END) as outlier_count,
    SUM(CASE WHEN {numeric_column} < ob.extreme_lower_bound OR {numeric_column} > ob.extreme_upper_bound THEN 1 ELSE 0 END) as extreme_outlier_count,
    CAST(SUM(CASE WHEN {numeric_column} < ob.lower_bound OR {numeric_column} > ob.upper_bound THEN 1 ELSE 0 END) * 100.0 /
         COUNT(*) AS DECIMAL(5,2)) as outlier_percentage
FROM {database}.{table_name}, outlier_bounds ob
WHERE {numeric_column} IS NOT NULL
;

-- =====================================================
-- 2. IDENTIFY OUTLIER RECORDS (IQR METHOD)
-- =====================================================

-- List actual outlier records
WITH outlier_bounds AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_column}) -
        1.5 * (PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_column}) -
               PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_column})) as lower_bound,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_column}) +
        1.5 * (PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_column}) -
               PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_column})) as upper_bound
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
)
SELECT
    {id_column},
    {numeric_column} as outlier_value,
    CASE
        WHEN {numeric_column} < ob.lower_bound THEN 'Lower Outlier'
        WHEN {numeric_column} > ob.upper_bound THEN 'Upper Outlier'
    END as outlier_type,
    CAST(ob.lower_bound AS DECIMAL(15,4)) as lower_threshold,
    CAST(ob.upper_bound AS DECIMAL(15,4)) as upper_threshold,
    CAST({numeric_column} - ob.lower_bound AS DECIMAL(15,4)) as distance_from_lower,
    CAST(ob.upper_bound - {numeric_column} AS DECIMAL(15,4)) as distance_from_upper
FROM {database}.{table_name} t, outlier_bounds ob
WHERE {numeric_column} IS NOT NULL
  AND ({numeric_column} < ob.lower_bound OR {numeric_column} > ob.upper_bound)
ORDER BY ABS({numeric_column} - (ob.lower_bound + ob.upper_bound) / 2) DESC
;

-- =====================================================
-- 3. Z-SCORE METHOD
-- =====================================================

-- Detect outliers using Z-score (assumes normal distribution)
WITH stats AS (
    SELECT
        AVG({numeric_column}) as mean_val,
        STDDEV({numeric_column}) as std_val
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
)
SELECT
    '{numeric_column}' as column_name,
    'Z-Score Method' as detection_method,
    CAST(s.mean_val AS DECIMAL(15,4)) as mean_value,
    CAST(s.std_val AS DECIMAL(15,4)) as std_deviation,
    CAST(s.mean_val - 3 * s.std_val AS DECIMAL(15,4)) as lower_threshold_3sd,
    CAST(s.mean_val + 3 * s.std_val AS DECIMAL(15,4)) as upper_threshold_3sd,
    COUNT(*) as total_records,
    SUM(CASE WHEN ABS({numeric_column} - s.mean_val) > 2 * s.std_val THEN 1 ELSE 0 END) as outliers_2sd,
    SUM(CASE WHEN ABS({numeric_column} - s.mean_val) > 3 * s.std_val THEN 1 ELSE 0 END) as outliers_3sd,
    CAST(SUM(CASE WHEN ABS({numeric_column} - s.mean_val) > 3 * s.std_val THEN 1 ELSE 0 END) * 100.0 /
         COUNT(*) AS DECIMAL(5,2)) as outlier_percentage_3sd
FROM {database}.{table_name} t, stats s
WHERE t.{numeric_column} IS NOT NULL
;

-- =====================================================
-- 4. IDENTIFY OUTLIER RECORDS (Z-SCORE METHOD)
-- =====================================================

-- List outliers with their Z-scores
WITH stats AS (
    SELECT
        AVG({numeric_column}) as mean_val,
        STDDEV({numeric_column}) as std_val
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
)
SELECT
    {id_column},
    {numeric_column} as value,
    CAST(({numeric_column} - s.mean_val) / NULLIF(s.std_val, 0) AS DECIMAL(10,4)) as z_score,
    CAST(ABS(({numeric_column} - s.mean_val) / NULLIF(s.std_val, 0)) AS DECIMAL(10,4)) as abs_z_score,
    CASE
        WHEN ABS(({numeric_column} - s.mean_val) / NULLIF(s.std_val, 0)) > 3 THEN 'Extreme Outlier (>3σ)'
        WHEN ABS(({numeric_column} - s.mean_val) / NULLIF(s.std_val, 0)) > 2 THEN 'Moderate Outlier (>2σ)'
        ELSE 'Mild Outlier'
    END as outlier_severity
FROM {database}.{table_name} t, stats s
WHERE {numeric_column} IS NOT NULL
  AND ABS(({numeric_column} - s.mean_val) / NULLIF(s.std_val, 0)) > 2
ORDER BY ABS(({numeric_column} - s.mean_val) / NULLIF(s.std_val, 0)) DESC
;

-- =====================================================
-- 5. MODIFIED Z-SCORE METHOD (Robust)
-- =====================================================

-- Modified Z-score using median and MAD (Median Absolute Deviation)
-- More robust to outliers than standard Z-score
WITH median_calc AS (
    SELECT
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY {numeric_column}) as median_val
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
),
mad_calc AS (
    SELECT
        m.median_val,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ABS({numeric_column} - m.median_val)) as mad_val
    FROM {database}.{table_name} t, median_calc m
    WHERE t.{numeric_column} IS NOT NULL
)
SELECT
    '{numeric_column}' as column_name,
    'Modified Z-Score Method' as detection_method,
    CAST(median_val AS DECIMAL(15,4)) as median_value,
    CAST(mad_val AS DECIMAL(15,4)) as mad_value,
    COUNT(*) as total_records,
    SUM(CASE WHEN ABS(0.6745 * ({numeric_column} - median_val) / NULLIF(mad_val, 0)) > 3.5 THEN 1 ELSE 0 END) as outlier_count,
    CAST(SUM(CASE WHEN ABS(0.6745 * ({numeric_column} - median_val) / NULLIF(mad_val, 0)) > 3.5 THEN 1 ELSE 0 END) * 100.0 /
         COUNT(*) AS DECIMAL(5,2)) as outlier_percentage
FROM {database}.{table_name} t, mad_calc m
WHERE t.{numeric_column} IS NOT NULL
;

-- =====================================================
-- 6. PERCENTILE-BASED OUTLIER DETECTION
-- =====================================================

-- Identify outliers based on extreme percentiles (1st and 99th)
WITH percentiles AS (
    SELECT
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY {numeric_column}) as p01,
        PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY {numeric_column}) as p05,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY {numeric_column}) as p95,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY {numeric_column}) as p99
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
)
SELECT
    '{numeric_column}' as column_name,
    'Percentile Method' as detection_method,
    CAST(p01 AS DECIMAL(15,4)) as percentile_1st,
    CAST(p05 AS DECIMAL(15,4)) as percentile_5th,
    CAST(p95 AS DECIMAL(15,4)) as percentile_95th,
    CAST(p99 AS DECIMAL(15,4)) as percentile_99th,
    COUNT(*) as total_records,
    SUM(CASE WHEN {numeric_column} < p.p01 OR {numeric_column} > p.p99 THEN 1 ELSE 0 END) as extreme_outliers_1pct,
    SUM(CASE WHEN {numeric_column} < p.p05 OR {numeric_column} > p.p95 THEN 1 ELSE 0 END) as outliers_5pct,
    CAST(SUM(CASE WHEN {numeric_column} < p.p01 OR {numeric_column} > p.p99 THEN 1 ELSE 0 END) * 100.0 /
         COUNT(*) AS DECIMAL(5,2)) as outlier_percentage_1pct
FROM {database}.{table_name} t, percentiles p
WHERE t.{numeric_column} IS NOT NULL
;

-- =====================================================
-- 7. MULTIVARIATE OUTLIER DETECTION (Mahalanobis Distance Approximation)
-- =====================================================

-- Simple distance-based multivariate outlier detection
-- Note: True Mahalanobis distance requires matrix operations
WITH standardized AS (
    SELECT
        {id_column},
        ({numeric_column_1} - AVG({numeric_column_1}) OVER()) / NULLIF(STDDEV({numeric_column_1}) OVER(), 0) as z1,
        ({numeric_column_2} - AVG({numeric_column_2}) OVER()) / NULLIF(STDDEV({numeric_column_2}) OVER(), 0) as z2,
        ({numeric_column_3} - AVG({numeric_column_3}) OVER()) / NULLIF(STDDEV({numeric_column_3}) OVER(), 0) as z3
    FROM {database}.{table_name}
    WHERE {numeric_column_1} IS NOT NULL
      AND {numeric_column_2} IS NOT NULL
      AND {numeric_column_3} IS NOT NULL
)
SELECT
    {id_column},
    CAST(SQRT(POWER(z1, 2) + POWER(z2, 2) + POWER(z3, 2)) AS DECIMAL(10,4)) as euclidean_distance,
    CASE
        WHEN SQRT(POWER(z1, 2) + POWER(z2, 2) + POWER(z3, 2)) > 5 THEN 'Extreme Multivariate Outlier'
        WHEN SQRT(POWER(z1, 2) + POWER(z2, 2) + POWER(z3, 2)) > 3 THEN 'Moderate Multivariate Outlier'
        ELSE 'Normal'
    END as outlier_classification
FROM standardized
WHERE SQRT(POWER(z1, 2) + POWER(z2, 2) + POWER(z3, 2)) > 3
ORDER BY SQRT(POWER(z1, 2) + POWER(z2, 2) + POWER(z3, 2)) DESC
;

-- =====================================================
-- 8. OUTLIER IMPACT ANALYSIS
-- =====================================================

-- Assess impact of outliers on statistics
WITH all_data AS (
    SELECT
        '{numeric_column}' as column_name,
        COUNT(*) as n,
        AVG({numeric_column}) as mean_with_outliers,
        STDDEV({numeric_column}) as std_with_outliers,
        MIN({numeric_column}) as min_val,
        MAX({numeric_column}) as max_val
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
),
outlier_bounds AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_column}) -
        1.5 * (PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_column}) -
               PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_column})) as lower_bound,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_column}) +
        1.5 * (PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_column}) -
               PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_column})) as upper_bound
    FROM {database}.{table_name}
    WHERE {numeric_column} IS NOT NULL
),
without_outliers AS (
    SELECT
        AVG({numeric_column}) as mean_without_outliers,
        STDDEV({numeric_column}) as std_without_outliers,
        COUNT(*) as n_without_outliers
    FROM {database}.{table_name}, outlier_bounds ob
    WHERE {numeric_column} IS NOT NULL
      AND {numeric_column} >= ob.lower_bound
      AND {numeric_column} <= ob.upper_bound
)
SELECT
    ad.column_name,
    ad.n as total_records,
    wo.n_without_outliers,
    ad.n - wo.n_without_outliers as outlier_count,
    CAST(ad.mean_with_outliers AS DECIMAL(15,4)) as mean_with_outliers,
    CAST(wo.mean_without_outliers AS DECIMAL(15,4)) as mean_without_outliers,
    CAST(ad.mean_with_outliers - wo.mean_without_outliers AS DECIMAL(15,4)) as mean_difference,
    CAST((ad.mean_with_outliers - wo.mean_without_outliers) * 100.0 /
         NULLIF(wo.mean_without_outliers, 0) AS DECIMAL(5,2)) as mean_pct_change,
    CAST(ad.std_with_outliers AS DECIMAL(15,4)) as std_with_outliers,
    CAST(wo.std_without_outliers AS DECIMAL(15,4)) as std_without_outliers,
    CAST((ad.std_with_outliers - wo.std_without_outliers) * 100.0 /
         NULLIF(wo.std_without_outliers, 0) AS DECIMAL(5,2)) as std_pct_change
FROM all_data ad, without_outliers wo
;

-- =====================================================
-- 9. CONSOLIDATED OUTLIER PROFILE TABLE
-- =====================================================

-- Create comprehensive outlier profile
CREATE MULTISET TABLE {database}.{table_name}_outlier_profile AS (
    WITH outlier_bounds AS (
        SELECT
            PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {numeric_column}) as q1,
            PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {numeric_column}) as q3,
            AVG({numeric_column}) as mean_val,
            STDDEV({numeric_column}) as std_val
        FROM {database}.{table_name}
        WHERE {numeric_column} IS NOT NULL
    ),
    thresholds AS (
        SELECT
            q1,
            q3,
            q3 - q1 as iqr,
            q1 - 1.5 * (q3 - q1) as iqr_lower,
            q3 + 1.5 * (q3 - q1) as iqr_upper,
            mean_val - 3 * std_val as zscore_lower,
            mean_val + 3 * std_val as zscore_upper
        FROM outlier_bounds
    )
    SELECT
        {id_column},
        {numeric_column} as value,
        CASE
            WHEN {numeric_column} < t.iqr_lower THEN 'Lower Outlier (IQR)'
            WHEN {numeric_column} > t.iqr_upper THEN 'Upper Outlier (IQR)'
            WHEN {numeric_column} < t.zscore_lower THEN 'Lower Outlier (Z-score)'
            WHEN {numeric_column} > t.zscore_upper THEN 'Upper Outlier (Z-score)'
        END as outlier_type,
        CAST(t.iqr_lower AS DECIMAL(15,4)) as iqr_lower_threshold,
        CAST(t.iqr_upper AS DECIMAL(15,4)) as iqr_upper_threshold,
        CAST(t.zscore_lower AS DECIMAL(15,4)) as zscore_lower_threshold,
        CAST(t.zscore_upper AS DECIMAL(15,4)) as zscore_upper_threshold,
        CURRENT_TIMESTAMP as detected_at
    FROM {database}.{table_name} t, thresholds t
    WHERE {numeric_column} IS NOT NULL
      AND ({numeric_column} < t.iqr_lower OR {numeric_column} > t.iqr_upper OR
           {numeric_column} < t.zscore_lower OR {numeric_column} > t.zscore_upper)
) WITH DATA PRIMARY INDEX ({id_column})
;

-- View outlier profile
SELECT * FROM {database}.{table_name}_outlier_profile
ORDER BY ABS(value - (iqr_lower_threshold + iqr_upper_threshold) / 2) DESC;

-- =====================================================
-- 10. OUTLIER SUMMARY REPORT
-- =====================================================

-- Summary of outlier detection across all methods
SELECT
    '{database}.{table_name}' as table_name,
    '{numeric_column}' as column_name,
    (SELECT COUNT(*) FROM {database}.{table_name} WHERE {numeric_column} IS NOT NULL) as total_records,
    (SELECT COUNT(*) FROM {database}.{table_name}_outlier_profile) as total_outliers_detected,
    CAST((SELECT COUNT(*) FROM {database}.{table_name}_outlier_profile) * 100.0 /
         (SELECT COUNT(*) FROM {database}.{table_name} WHERE {numeric_column} IS NOT NULL) AS DECIMAL(5,2)) as outlier_percentage,
    CASE
        WHEN CAST((SELECT COUNT(*) FROM {database}.{table_name}_outlier_profile) * 100.0 /
                  (SELECT COUNT(*) FROM {database}.{table_name} WHERE {numeric_column} IS NOT NULL) AS DECIMAL(5,2)) < 5
        THEN 'LOW - Few outliers detected'
        WHEN CAST((SELECT COUNT(*) FROM {database}.{table_name}_outlier_profile) * 100.0 /
                  (SELECT COUNT(*) FROM {database}.{table_name} WHERE {numeric_column} IS NOT NULL) AS DECIMAL(5,2)) < 10
        THEN 'MODERATE - Some outliers present'
        ELSE 'HIGH - Many outliers detected'
    END as outlier_severity,
    CURRENT_TIMESTAMP as analysis_date
;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {table_name} - Your table name
--    {numeric_column} - Numeric column to analyze
--    {numeric_column_1}, {numeric_column_2}, {numeric_column_3} - For multivariate
--    {id_column} - Unique identifier column
--
-- 2. Choose detection method(s):
--    - IQR (Sections 1-2): Best for general use, robust
--    - Z-score (Sections 3-4): Assumes normality
--    - Modified Z-score (Section 5): Most robust
--    - Percentile (Section 6): Simple, intuitive
--    - Multivariate (Section 7): For multiple dimensions
--
-- 3. Execute Section 9 to create consolidated outlier table
--
-- 4. Analyze impact and decide on treatment:
--    - Investigate: Understand why outliers exist
--    - Remove: If data errors
--    - Transform: Apply log, sqrt, or other transformations
--    - Cap: Winsorize at percentiles
--    - Keep: If legitimate extreme values
--
-- =====================================================
