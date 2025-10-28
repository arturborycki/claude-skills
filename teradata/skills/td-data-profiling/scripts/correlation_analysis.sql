-- =====================================================
-- Correlation Analysis
-- =====================================================
-- Purpose: Analyze relationships between numeric variables
-- Uses: TD_Correlation, Pearson correlation coefficient
-- =====================================================

-- =====================================================
-- 1. CORRELATION MATRIX USING TD_CORRELATION
-- =====================================================

-- Generate correlation matrix for all numeric columns
SELECT * FROM TD_Correlation(
    ON {database}.{table_name}
    USING
    TargetColumns({numeric_columns})  -- e.g., 'age', 'income', 'credit_score', 'purchase_amount'
    Method('Pearson')  -- or 'Spearman' for non-parametric
) AS dt
ORDER BY column1, column2
;

-- =====================================================
-- 2. PAIRWISE CORRELATION (Native SQL)
-- =====================================================

-- Calculate Pearson correlation between two variables
WITH stats AS (
    SELECT
        AVG({numeric_column_1}) as mean_x,
        AVG({numeric_column_2}) as mean_y,
        STDDEV({numeric_column_1}) as std_x,
        STDDEV({numeric_column_2}) as std_y,
        COUNT(*) as n
    FROM {database}.{table_name}
    WHERE {numeric_column_1} IS NOT NULL
      AND {numeric_column_2} IS NOT NULL
),
covariance AS (
    SELECT
        SUM(({numeric_column_1} - s.mean_x) * ({numeric_column_2} - s.mean_y)) / (s.n - 1) as cov_xy
    FROM {database}.{table_name} t, stats s
    WHERE t.{numeric_column_1} IS NOT NULL
      AND t.{numeric_column_2} IS NOT NULL
)
SELECT
    '{numeric_column_1}' as variable_1,
    '{numeric_column_2}' as variable_2,
    s.n as sample_size,
    CAST(c.cov_xy / NULLIF((s.std_x * s.std_y), 0) AS DECIMAL(10,6)) as correlation_coefficient,
    CASE
        WHEN ABS(c.cov_xy / NULLIF((s.std_x * s.std_y), 0)) < 0.3 THEN 'Weak'
        WHEN ABS(c.cov_xy / NULLIF((s.std_x * s.std_y), 0)) < 0.7 THEN 'Moderate'
        ELSE 'Strong'
    END as correlation_strength,
    CASE
        WHEN c.cov_xy / NULLIF((s.std_x * s.std_y), 0) > 0 THEN 'Positive'
        WHEN c.cov_xy / NULLIF((s.std_x * s.std_y), 0) < 0 THEN 'Negative'
        ELSE 'None'
    END as correlation_direction
FROM stats s, covariance c
;

-- =====================================================
-- 3. CORRELATION MATRIX (All Numeric Pairs)
-- =====================================================

-- Create comprehensive correlation matrix
-- Note: This example shows 4 columns; extend for all numeric columns
WITH correlations AS (
    -- Column 1 with Column 2
    SELECT
        '{numeric_column_1}' as variable_1,
        '{numeric_column_2}' as variable_2,
        CORR({numeric_column_1}, {numeric_column_2}) as correlation
    FROM {database}.{table_name}
    WHERE {numeric_column_1} IS NOT NULL AND {numeric_column_2} IS NOT NULL

    UNION ALL

    -- Column 1 with Column 3
    SELECT
        '{numeric_column_1}' as variable_1,
        '{numeric_column_3}' as variable_2,
        CORR({numeric_column_1}, {numeric_column_3}) as correlation
    FROM {database}.{table_name}
    WHERE {numeric_column_1} IS NOT NULL AND {numeric_column_3} IS NOT NULL

    UNION ALL

    -- Column 2 with Column 3
    SELECT
        '{numeric_column_2}' as variable_1,
        '{numeric_column_3}' as variable_2,
        CORR({numeric_column_2}, {numeric_column_3}) as correlation
    FROM {database}.{table_name}
    WHERE {numeric_column_2} IS NOT NULL AND {numeric_column_3} IS NOT NULL

    -- Add more pairs as needed...
)
SELECT
    variable_1,
    variable_2,
    CAST(correlation AS DECIMAL(10,6)) as correlation_coefficient,
    CAST(ABS(correlation) AS DECIMAL(10,6)) as absolute_correlation,
    CASE
        WHEN ABS(correlation) >= 0.9 THEN 'Very Strong'
        WHEN ABS(correlation) >= 0.7 THEN 'Strong'
        WHEN ABS(correlation) >= 0.4 THEN 'Moderate'
        WHEN ABS(correlation) >= 0.2 THEN 'Weak'
        ELSE 'Very Weak'
    END as strength_category,
    CASE
        WHEN correlation > 0 THEN 'Positive'
        WHEN correlation < 0 THEN 'Negative'
        ELSE 'None'
    END as direction
FROM correlations
ORDER BY ABS(correlation) DESC
;

-- =====================================================
-- 4. HIGHLY CORRELATED PAIRS DETECTION
-- =====================================================

-- Identify strongly correlated variable pairs (|r| > 0.7)
WITH correlation_pairs AS (
    -- Generate all pairwise correlations
    SELECT
        '{numeric_column_1}' as var1,
        '{numeric_column_2}' as var2,
        CORR({numeric_column_1}, {numeric_column_2}) as corr_coef
    FROM {database}.{table_name}
    WHERE {numeric_column_1} IS NOT NULL AND {numeric_column_2} IS NOT NULL

    UNION ALL

    SELECT
        '{numeric_column_1}' as var1,
        '{numeric_column_3}' as var2,
        CORR({numeric_column_1}, {numeric_column_3}) as corr_coef
    FROM {database}.{table_name}
    WHERE {numeric_column_1} IS NOT NULL AND {numeric_column_3} IS NOT NULL

    -- Add all other pairs...
)
SELECT
    var1 as variable_1,
    var2 as variable_2,
    CAST(corr_coef AS DECIMAL(10,6)) as correlation,
    CASE
        WHEN ABS(corr_coef) >= 0.9 THEN 'CRITICAL - Potential Redundancy'
        WHEN ABS(corr_coef) >= 0.7 THEN 'HIGH - Multicollinearity Risk'
        ELSE 'MODERATE - Monitor'
    END as multicollinearity_risk,
    CASE
        WHEN corr_coef > 0 THEN 'Variables increase together'
        ELSE 'Variables move in opposite directions'
    END as relationship_interpretation
FROM correlation_pairs
WHERE ABS(corr_coef) > 0.7
ORDER BY ABS(corr_coef) DESC
;

-- =====================================================
-- 5. CORRELATION WITH TARGET VARIABLE
-- =====================================================

-- Correlations of all features with target variable (for predictive modeling)
SELECT
    feature_name,
    CAST(correlation_with_target AS DECIMAL(10,6)) as correlation,
    CAST(ABS(correlation_with_target) AS DECIMAL(10,6)) as absolute_correlation,
    CASE
        WHEN ABS(correlation_with_target) >= 0.7 THEN 'Strong Predictor'
        WHEN ABS(correlation_with_target) >= 0.4 THEN 'Moderate Predictor'
        WHEN ABS(correlation_with_target) >= 0.2 THEN 'Weak Predictor'
        ELSE 'Poor Predictor'
    END as predictive_strength,
    CASE
        WHEN correlation_with_target > 0 THEN 'Positive (increases with target)'
        WHEN correlation_with_target < 0 THEN 'Negative (decreases with target)'
        ELSE 'No Linear Relationship'
    END as relationship
FROM (
    SELECT
        '{numeric_column_1}' as feature_name,
        CORR({numeric_column_1}, {target_column}) as correlation_with_target
    FROM {database}.{table_name}
    WHERE {numeric_column_1} IS NOT NULL AND {target_column} IS NOT NULL

    UNION ALL

    SELECT
        '{numeric_column_2}' as feature_name,
        CORR({numeric_column_2}, {target_column}) as correlation_with_target
    FROM {database}.{table_name}
    WHERE {numeric_column_2} IS NOT NULL AND {target_column} IS NOT NULL

    -- Add all features...
) AS target_correlations
ORDER BY ABS(correlation_with_target) DESC
;

-- =====================================================
-- 6. COVARIANCE MATRIX
-- =====================================================

-- Calculate covariance between variables
SELECT
    '{numeric_column_1}' as variable_1,
    '{numeric_column_2}' as variable_2,
    COUNT(*) as n,
    AVG({numeric_column_1}) as mean_var1,
    AVG({numeric_column_2}) as mean_var2,
    COVAR_POP({numeric_column_1}, {numeric_column_2}) as population_covariance,
    COVAR_SAMP({numeric_column_1}, {numeric_column_2}) as sample_covariance,
    CORR({numeric_column_1}, {numeric_column_2}) as correlation
FROM {database}.{table_name}
WHERE {numeric_column_1} IS NOT NULL
  AND {numeric_column_2} IS NOT NULL
;

-- =====================================================
-- 7. MULTICOLLINEARITY DETECTION (VIF Estimation)
-- =====================================================

-- Variance Inflation Factor (VIF) estimation
-- VIF = 1 / (1 - R²) where R² is from regression on other variables
-- This is a simplified indicator; true VIF requires regression

WITH correlations AS (
    SELECT
        '{numeric_column_1}' as var_name,
        POWER(CORR({numeric_column_1}, {numeric_column_2}), 2) as r_squared_proxy
    FROM {database}.{table_name}
    WHERE {numeric_column_1} IS NOT NULL AND {numeric_column_2} IS NOT NULL
)
SELECT
    var_name,
    CAST(r_squared_proxy AS DECIMAL(10,6)) as r_squared_with_other,
    CAST(1.0 / NULLIF((1 - r_squared_proxy), 0) AS DECIMAL(10,4)) as vif_estimate,
    CASE
        WHEN 1.0 / NULLIF((1 - r_squared_proxy), 0) > 10 THEN 'SEVERE - High Multicollinearity'
        WHEN 1.0 / NULLIF((1 - r_squared_proxy), 0) > 5 THEN 'MODERATE - Some Multicollinearity'
        ELSE 'LOW - Acceptable'
    END as multicollinearity_level
FROM correlations
;

-- =====================================================
-- 8. CORRELATION HEATMAP DATA
-- =====================================================

-- Generate data for correlation heatmap visualization
-- Pivot-style output for easier visualization
SELECT
    '{numeric_column_1}' as row_variable,
    CAST(CORR({numeric_column_1}, {numeric_column_1}) AS DECIMAL(5,3)) as "{numeric_column_1}",
    CAST(CORR({numeric_column_1}, {numeric_column_2}) AS DECIMAL(5,3)) as "{numeric_column_2}",
    CAST(CORR({numeric_column_1}, {numeric_column_3}) AS DECIMAL(5,3)) as "{numeric_column_3}",
    CAST(CORR({numeric_column_1}, {numeric_column_4}) AS DECIMAL(5,3)) as "{numeric_column_4}"
FROM {database}.{table_name}

UNION ALL

SELECT
    '{numeric_column_2}' as row_variable,
    CAST(CORR({numeric_column_2}, {numeric_column_1}) AS DECIMAL(5,3)) as "{numeric_column_1}",
    CAST(CORR({numeric_column_2}, {numeric_column_2}) AS DECIMAL(5,3)) as "{numeric_column_2}",
    CAST(CORR({numeric_column_2}, {numeric_column_3}) AS DECIMAL(5,3)) as "{numeric_column_3}",
    CAST(CORR({numeric_column_2}, {numeric_column_4}) AS DECIMAL(5,3)) as "{numeric_column_4}"
FROM {database}.{table_name}

-- Add more rows for each numeric column...
;

-- =====================================================
-- 9. CORRELATION PROFILE TABLE
-- =====================================================

-- Create consolidated correlation profile
CREATE MULTISET TABLE {database}.{table_name}_correlation_profile AS (
    SELECT
        variable_1,
        variable_2,
        CAST(correlation AS DECIMAL(10,6)) as correlation_coefficient,
        CAST(ABS(correlation) AS DECIMAL(10,6)) as absolute_correlation,
        CASE
            WHEN ABS(correlation) >= 0.9 THEN 'Very Strong'
            WHEN ABS(correlation) >= 0.7 THEN 'Strong'
            WHEN ABS(correlation) >= 0.4 THEN 'Moderate'
            WHEN ABS(correlation) >= 0.2 THEN 'Weak'
            ELSE 'Very Weak'
        END as correlation_strength,
        CASE
            WHEN correlation > 0 THEN 'Positive'
            WHEN correlation < 0 THEN 'Negative'
            ELSE 'None'
        END as correlation_direction,
        CASE
            WHEN ABS(correlation) >= 0.9 THEN 'Consider removing one variable'
            WHEN ABS(correlation) >= 0.7 THEN 'Monitor for multicollinearity'
            ELSE 'No action needed'
        END as recommendation,
        CURRENT_TIMESTAMP as profiled_at
    FROM (
        -- All pairwise correlations
        SELECT
            '{numeric_column_1}' as variable_1,
            '{numeric_column_2}' as variable_2,
            CORR({numeric_column_1}, {numeric_column_2}) as correlation
        FROM {database}.{table_name}
        WHERE {numeric_column_1} IS NOT NULL AND {numeric_column_2} IS NOT NULL

        -- Add all other pairs...
    ) AS all_correlations
) WITH DATA PRIMARY INDEX (variable_1, variable_2)
;

-- View correlation profile
SELECT * FROM {database}.{table_name}_correlation_profile
ORDER BY absolute_correlation DESC;

-- =====================================================
-- 10. CORRELATION INSIGHTS SUMMARY
-- =====================================================

-- Summary of correlation analysis findings
WITH correlation_stats AS (
    SELECT
        COUNT(*) as total_pairs,
        SUM(CASE WHEN ABS(correlation_coefficient) >= 0.9 THEN 1 ELSE 0 END) as very_strong_correlations,
        SUM(CASE WHEN ABS(correlation_coefficient) >= 0.7 AND ABS(correlation_coefficient) < 0.9 THEN 1 ELSE 0 END) as strong_correlations,
        SUM(CASE WHEN ABS(correlation_coefficient) >= 0.4 AND ABS(correlation_coefficient) < 0.7 THEN 1 ELSE 0 END) as moderate_correlations,
        SUM(CASE WHEN ABS(correlation_coefficient) < 0.4 THEN 1 ELSE 0 END) as weak_correlations,
        AVG(ABS(correlation_coefficient)) as avg_absolute_correlation,
        MAX(ABS(correlation_coefficient)) as max_correlation
    FROM {database}.{table_name}_correlation_profile
)
SELECT
    '{database}.{table_name}' as table_name,
    total_pairs,
    very_strong_correlations,
    strong_correlations,
    moderate_correlations,
    weak_correlations,
    CAST(avg_absolute_correlation AS DECIMAL(5,3)) as avg_abs_correlation,
    CAST(max_correlation AS DECIMAL(5,3)) as strongest_correlation,
    CASE
        WHEN very_strong_correlations > 0 THEN 'HIGH - Feature redundancy detected'
        WHEN strong_correlations > total_pairs * 0.3 THEN 'MODERATE - Some multicollinearity'
        ELSE 'LOW - Features relatively independent'
    END as multicollinearity_assessment,
    CURRENT_TIMESTAMP as analysis_date
FROM correlation_stats
;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {table_name} - Your table name
--    {numeric_columns} - Comma-separated list for TD_Correlation
--    {numeric_column_1}, {numeric_column_2}, etc. - Individual numeric columns
--    {target_column} - Target variable for predictive modeling (optional)
--
-- 2. Execute Section 1 for automated correlation analysis using TD_Correlation
--    OR Sections 2-8 for detailed native SQL analysis
--
-- 3. Execute Section 9 to create consolidated correlation profile
--
-- 4. Use results for:
--    - Feature selection (remove highly correlated features)
--    - Multicollinearity detection before modeling
--    - Understanding variable relationships
--    - Identifying potential data issues
--
-- =====================================================
