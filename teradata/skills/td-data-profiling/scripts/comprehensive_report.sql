-- =====================================================
-- Comprehensive Data Profiling Report
-- =====================================================
-- Purpose: Consolidated profiling report combining all analyses
-- Output: Executive summary and detailed findings
-- =====================================================

-- =====================================================
-- 1. EXECUTIVE SUMMARY
-- =====================================================

-- High-level overview of profiling results
SELECT
    '{database}.{table_name}' as table_full_name,
    (SELECT COUNT(*) FROM {database}.{table_name}) as total_rows,
    (SELECT COUNT(*) FROM DBC.ColumnsV WHERE DatabaseName = '{database}' AND TableName = '{table_name}') as total_columns,
    (SELECT COUNT(*) FROM DBC.ColumnsV WHERE DatabaseName = '{database}' AND TableName = '{table_name}'
     AND ColumnType IN ('I', 'I1', 'I2', 'I8', 'BI', 'BF', 'F', 'D', 'N')) as numeric_columns,
    (SELECT COUNT(*) FROM DBC.ColumnsV WHERE DatabaseName = '{database}' AND TableName = '{table_name}'
     AND ColumnType IN ('CF', 'CV')) as text_columns,
    (SELECT COUNT(*) FROM DBC.ColumnsV WHERE DatabaseName = '{database}' AND TableName = '{table_name}'
     AND ColumnType IN ('DA', 'TS', 'AT', 'TZ')) as datetime_columns,
    CAST((SELECT AVG(overall_quality_score) FROM {database}.{table_name}_quality_scorecard) AS DECIMAL(5,2)) as avg_quality_score,
    CASE
        WHEN (SELECT AVG(overall_quality_score) FROM {database}.{table_name}_quality_scorecard) >= 90 THEN 'EXCELLENT'
        WHEN (SELECT AVG(overall_quality_score) FROM {database}.{table_name}_quality_scorecard) >= 70 THEN 'GOOD'
        WHEN (SELECT AVG(overall_quality_score) FROM {database}.{table_name}_quality_scorecard) >= 50 THEN 'FAIR'
        ELSE 'POOR'
    END as overall_data_quality,
    CURRENT_TIMESTAMP as report_generated_at
;

-- =====================================================
-- 2. DATA COMPLETENESS SUMMARY
-- =====================================================

-- Summary of missing values across all columns
SELECT
    'Completeness Overview' as metric_category,
    COUNT(*) as total_columns_assessed,
    SUM(CASE WHEN completeness_score >= 95 THEN 1 ELSE 0 END) as complete_columns,
    SUM(CASE WHEN completeness_score BETWEEN 80 AND 94 THEN 1 ELSE 0 END) as mostly_complete_columns,
    SUM(CASE WHEN completeness_score BETWEEN 50 AND 79 THEN 1 ELSE 0 END) as partial_columns,
    SUM(CASE WHEN completeness_score < 50 THEN 1 ELSE 0 END) as incomplete_columns,
    CAST(AVG(completeness_score) AS DECIMAL(5,2)) as avg_completeness_score
FROM {database}.{table_name}_quality_scorecard
;

-- Columns with significant missing data
SELECT
    column_name,
    completeness_score,
    100 - completeness_score as missing_percentage,
    'Review and consider imputation strategy' as recommendation
FROM {database}.{table_name}_quality_scorecard
WHERE completeness_score < 80
ORDER BY completeness_score ASC
;

-- =====================================================
-- 3. NUMERIC COLUMN SUMMARY
-- =====================================================

-- Summary statistics for all numeric columns
SELECT
    column_name,
    total_count,
    non_null_count,
    CAST(null_percentage AS DECIMAL(5,2)) as null_pct,
    distinct_count,
    CAST(min_value AS DECIMAL(15,4)) as min_val,
    CAST(q1 AS DECIMAL(15,4)) as q1,
    CAST(median AS DECIMAL(15,4)) as median,
    CAST(mean_value AS DECIMAL(15,4)) as mean,
    CAST(q3 AS DECIMAL(15,4)) as q3,
    CAST(max_value AS DECIMAL(15,4)) as max_val,
    CAST(std_dev AS DECIMAL(15,4)) as std_deviation,
    CAST(coefficient_of_variation AS DECIMAL(5,2)) as cv_pct
FROM {database}.{table_name}_numeric_profile
ORDER BY column_name
;

-- =====================================================
-- 4. CATEGORICAL COLUMN SUMMARY
-- =====================================================

-- Summary statistics for all categorical columns
SELECT
    column_name,
    total_count,
    non_null_count,
    CAST(null_percentage AS DECIMAL(5,2)) as null_pct,
    distinct_count,
    CAST(cardinality_ratio AS DECIMAL(5,2)) as cardinality_pct,
    mode_value,
    mode_frequency,
    CAST(mode_percentage AS DECIMAL(5,2)) as mode_pct,
    CAST(imbalance_ratio AS DECIMAL(10,2)) as imbalance,
    CASE
        WHEN distinct_count = 1 THEN 'Single value - No variance'
        WHEN distinct_count > 50 THEN 'High cardinality - Consider grouping'
        WHEN imbalance_ratio > 10 THEN 'Highly imbalanced distribution'
        ELSE 'Normal distribution'
    END as notes
FROM {database}.{table_name}_categorical_profile
ORDER BY column_name
;

-- =====================================================
-- 5. DISTRIBUTION ANALYSIS SUMMARY
-- =====================================================

-- Distribution characteristics for numeric columns
SELECT
    column_name,
    CAST(mean AS DECIMAL(15,4)) as mean_value,
    CAST(median AS DECIMAL(15,4)) as median_value,
    CAST(std_dev AS DECIMAL(15,4)) as std_deviation,
    CAST(skewness AS DECIMAL(10,4)) as skewness,
    CAST(kurtosis AS DECIMAL(10,4)) as kurtosis,
    distribution_shape,
    CASE
        WHEN ABS(skewness) > 1 THEN 'Consider log or Box-Cox transformation'
        WHEN ABS(kurtosis) > 3 THEN 'Heavy tails - Check for outliers'
        ELSE 'Distribution shape acceptable'
    END as transformation_recommendation
FROM {database}.{table_name}_distribution_profile
ORDER BY ABS(skewness) DESC
;

-- =====================================================
-- 6. CORRELATION ANALYSIS SUMMARY
-- =====================================================

-- High correlation pairs (potential multicollinearity)
SELECT
    variable_1,
    variable_2,
    CAST(correlation_coefficient AS DECIMAL(10,6)) as correlation,
    correlation_strength,
    correlation_direction,
    recommendation
FROM {database}.{table_name}_correlation_profile
WHERE ABS(correlation_coefficient) >= 0.7
ORDER BY ABS(correlation_coefficient) DESC
;

-- Correlation statistics
SELECT
    'Correlation Analysis' as analysis_type,
    COUNT(*) as total_correlations_analyzed,
    SUM(CASE WHEN correlation_strength IN ('Very Strong', 'Strong') THEN 1 ELSE 0 END) as strong_correlations,
    SUM(CASE WHEN correlation_strength = 'Moderate' THEN 1 ELSE 0 END) as moderate_correlations,
    SUM(CASE WHEN correlation_strength IN ('Weak', 'Very Weak') THEN 1 ELSE 0 END) as weak_correlations,
    CASE
        WHEN SUM(CASE WHEN ABS(correlation_coefficient) >= 0.9 THEN 1 ELSE 0 END) > 0
        THEN 'WARNING: High multicollinearity detected - Consider feature selection'
        WHEN SUM(CASE WHEN ABS(correlation_coefficient) >= 0.7 THEN 1 ELSE 0 END) > 0
        THEN 'MODERATE: Some correlated features - Monitor in modeling'
        ELSE 'GOOD: Features relatively independent'
    END as multicollinearity_assessment
FROM {database}.{table_name}_correlation_profile
;

-- =====================================================
-- 7. OUTLIER ANALYSIS SUMMARY
-- =====================================================

-- Outlier statistics per column
SELECT
    '{numeric_column}' as column_name,
    COUNT(*) as total_outliers,
    COUNT(DISTINCT outlier_type) as outlier_types_detected,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name} WHERE {numeric_column} IS NOT NULL) AS DECIMAL(5,2)) as outlier_percentage,
    MIN(value) as min_outlier_value,
    MAX(value) as max_outlier_value,
    CASE
        WHEN COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name} WHERE {numeric_column} IS NOT NULL) < 5
        THEN 'LOW - Few outliers'
        WHEN COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name} WHERE {numeric_column} IS NOT NULL) < 10
        THEN 'MODERATE - Some outliers'
        ELSE 'HIGH - Many outliers require investigation'
    END as outlier_severity,
    'Investigate and determine if outliers are errors or valid extreme values' as recommendation
FROM {database}.{table_name}_outlier_profile
;

-- =====================================================
-- 8. DATA QUALITY SCORECARD
-- =====================================================

-- Column-level quality scores
SELECT
    column_name,
    CAST(completeness_score AS DECIMAL(5,2)) as completeness,
    CAST(uniqueness_score AS DECIMAL(5,2)) as uniqueness,
    CAST(validity_score AS DECIMAL(5,2)) as validity,
    CAST(consistency_score AS DECIMAL(5,2)) as consistency,
    CAST(overall_quality_score AS DECIMAL(5,2)) as overall_quality,
    quality_grade,
    CASE
        WHEN overall_quality_score >= 90 THEN 'No action needed'
        WHEN overall_quality_score >= 70 THEN 'Minor improvements recommended'
        WHEN overall_quality_score >= 50 THEN 'Significant improvements needed'
        ELSE 'Critical - Immediate attention required'
    END as action_required
FROM {database}.{table_name}_quality_scorecard
ORDER BY overall_quality_score ASC
;

-- =====================================================
-- 9. TOP DATA QUALITY ISSUES
-- =====================================================

-- Prioritized list of data quality issues
WITH issues AS (
    SELECT
        column_name,
        'Missing Data' as issue_type,
        100 - completeness_score as severity_score,
        'HIGH' as priority,
        'Implement imputation strategy or investigate cause' as recommended_action
    FROM {database}.{table_name}_quality_scorecard
    WHERE completeness_score < 80

    UNION ALL

    SELECT
        column_name,
        'Low Uniqueness' as issue_type,
        100 - uniqueness_score as severity_score,
        'MEDIUM' as priority,
        'Review for duplicates or data entry errors' as recommended_action
    FROM {database}.{table_name}_quality_scorecard
    WHERE uniqueness_score < 70

    UNION ALL

    SELECT
        column_name,
        'Invalid Values' as issue_type,
        100 - validity_score as severity_score,
        'HIGH' as priority,
        'Validate data ranges and formats' as recommended_action
    FROM {database}.{table_name}_quality_scorecard
    WHERE validity_score < 80

    UNION ALL

    SELECT
        column_name,
        'Inconsistent Format' as issue_type,
        100 - consistency_score as severity_score,
        'MEDIUM' as priority,
        'Standardize data formats and values' as recommended_action
    FROM {database}.{table_name}_quality_scorecard
    WHERE consistency_score < 70
)
SELECT
    ROW_NUMBER() OVER (ORDER BY severity_score DESC) as issue_rank,
    column_name,
    issue_type,
    CAST(severity_score AS DECIMAL(5,2)) as severity,
    priority,
    recommended_action
FROM issues
ORDER BY severity_score DESC
FETCH FIRST 20 ROWS ONLY
;

-- =====================================================
-- 10. PROFILING RECOMMENDATIONS
-- =====================================================

-- Actionable recommendations based on profiling results
SELECT
    recommendation_category,
    recommendation_text,
    priority,
    affected_columns
FROM (
    -- Missing Data Recommendations
    SELECT
        'Data Completeness' as recommendation_category,
        'Address missing values in columns with < 80% completeness' as recommendation_text,
        'HIGH' as priority,
        COUNT(*) as affected_columns
    FROM {database}.{table_name}_quality_scorecard
    WHERE completeness_score < 80
    HAVING COUNT(*) > 0

    UNION ALL

    -- High Cardinality Recommendations
    SELECT
        'Categorical Variables' as recommendation_category,
        'Review high cardinality categorical columns (>50 distinct values)' as recommendation_text,
        'MEDIUM' as priority,
        COUNT(*) as affected_columns
    FROM {database}.{table_name}_categorical_profile
    WHERE distinct_count > 50
    HAVING COUNT(*) > 0

    UNION ALL

    -- Skewed Distribution Recommendations
    SELECT
        'Data Transformation' as recommendation_category,
        'Consider transformation for highly skewed numeric columns (|skewness| > 1)' as recommendation_text,
        'MEDIUM' as priority,
        COUNT(*) as affected_columns
    FROM {database}.{table_name}_distribution_profile
    WHERE ABS(skewness) > 1
    HAVING COUNT(*) > 0

    UNION ALL

    -- Multicollinearity Recommendations
    SELECT
        'Feature Selection' as recommendation_category,
        'Address multicollinearity - remove highly correlated features (|r| > 0.9)' as recommendation_text,
        'HIGH' as priority,
        COUNT(DISTINCT variable_1) as affected_columns
    FROM {database}.{table_name}_correlation_profile
    WHERE ABS(correlation_coefficient) > 0.9
    HAVING COUNT(DISTINCT variable_1) > 0

    UNION ALL

    -- Outlier Recommendations
    SELECT
        'Outlier Treatment' as recommendation_category,
        'Investigate and treat outliers detected in numeric columns' as recommendation_text,
        'MEDIUM' as priority,
        COUNT(DISTINCT '{numeric_column}') as affected_columns
    FROM {database}.{table_name}_outlier_profile
    HAVING COUNT(DISTINCT '{numeric_column}') > 0
) AS recommendations
ORDER BY
    CASE priority
        WHEN 'HIGH' THEN 1
        WHEN 'MEDIUM' THEN 2
        ELSE 3
    END,
    affected_columns DESC
;

-- =====================================================
-- 11. PROFILING METADATA
-- =====================================================

-- Metadata about the profiling process
SELECT
    '{database}.{table_name}' as table_name,
    'Comprehensive Data Profiling' as analysis_type,
    'COMPLETED' as status,
    (SELECT COUNT(*) FROM {database}.{table_name}) as total_rows_profiled,
    (SELECT COUNT(*) FROM DBC.ColumnsV WHERE DatabaseName = '{database}' AND TableName = '{table_name}') as total_columns_profiled,
    (SELECT COUNT(*) FROM {database}.{table_name}_numeric_profile) as numeric_columns_analyzed,
    (SELECT COUNT(*) FROM {database}.{table_name}_categorical_profile) as categorical_columns_analyzed,
    (SELECT COUNT(*) FROM {database}.{table_name}_correlation_profile) as correlation_pairs_analyzed,
    (SELECT COUNT(*) FROM {database}.{table_name}_outlier_profile) as outliers_detected,
    CURRENT_TIMESTAMP as profiling_completed_at,
    'Teradata ClearScape Analytics' as profiling_engine
;

-- =====================================================
-- 12. EXPORT SUMMARY FOR REPORTING
-- =====================================================

-- Create final consolidated report table
CREATE MULTISET TABLE {database}.{table_name}_profiling_report AS (
    SELECT
        '{database}.{table_name}' as table_name,
        'Executive Summary' as section,
        1 as section_order,
        'Overall Quality Score: ' || CAST((SELECT AVG(overall_quality_score) FROM {database}.{table_name}_quality_scorecard) AS VARCHAR(10)) ||
        ' | Total Rows: ' || CAST((SELECT COUNT(*) FROM {database}.{table_name}) AS VARCHAR(20)) ||
        ' | Total Columns: ' || CAST((SELECT COUNT(*) FROM DBC.ColumnsV WHERE DatabaseName = '{database}' AND TableName = '{table_name}') AS VARCHAR(10)) as summary_text,
        CURRENT_TIMESTAMP as generated_at

    UNION ALL

    SELECT
        '{database}.{table_name}' as table_name,
        'Data Quality Issues' as section,
        2 as section_order,
        'Columns with issues: ' || CAST(COUNT(*) AS VARCHAR(10)) as summary_text,
        CURRENT_TIMESTAMP as generated_at
    FROM {database}.{table_name}_quality_scorecard
    WHERE overall_quality_score < 80

    UNION ALL

    SELECT
        '{database}.{table_name}' as table_name,
        'Correlation Findings' as section,
        3 as section_order,
        'Highly correlated pairs: ' || CAST(COUNT(*) AS VARCHAR(10)) as summary_text,
        CURRENT_TIMESTAMP as generated_at
    FROM {database}.{table_name}_correlation_profile
    WHERE ABS(correlation_coefficient) > 0.7

    UNION ALL

    SELECT
        '{database}.{table_name}' as table_name,
        'Outlier Detection' as section,
        4 as section_order,
        'Total outliers detected: ' || CAST(COUNT(*) AS VARCHAR(10)) as summary_text,
        CURRENT_TIMESTAMP as generated_at
    FROM {database}.{table_name}_outlier_profile
) WITH DATA PRIMARY INDEX (table_name, section)
;

-- View comprehensive report
SELECT * FROM {database}.{table_name}_profiling_report
ORDER BY section_order;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {table_name} - Your table name
--    {numeric_column} - Numeric column name (for outlier summary)
--
-- 2. Ensure all prerequisite profiling tables exist:
--    - {table_name}_numeric_profile
--    - {table_name}_categorical_profile
--    - {table_name}_distribution_profile
--    - {table_name}_correlation_profile
--    - {table_name}_outlier_profile
--    - {table_name}_quality_scorecard
--
-- 3. Execute sections to generate comprehensive report
--
-- 4. Section 12 creates final consolidated report table
--
-- 5. Use report to:
--    - Understand data characteristics
--    - Identify data quality issues
--    - Prioritize data cleansing efforts
--    - Inform feature engineering decisions
--    - Document data properties for stakeholders
--
-- =====================================================
