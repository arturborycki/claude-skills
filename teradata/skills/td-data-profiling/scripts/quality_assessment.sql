-- =====================================================
-- Data Quality Assessment
-- =====================================================
-- Purpose: Comprehensive data quality metrics and scoring
-- Output: Quality scores, completeness, validity, consistency
-- =====================================================

-- =====================================================
-- 1. OVERALL TABLE QUALITY SUMMARY
-- =====================================================

-- High-level quality metrics
SELECT
    '{database}.{table_name}' as table_name,
    COUNT(*) as total_rows,
    (SELECT COUNT(*) FROM DBC.ColumnsV WHERE DatabaseName = '{database}' AND TableName = '{table_name}') as total_columns,
    CURRENT_TIMESTAMP as assessment_timestamp
FROM {database}.{table_name}
;

-- =====================================================
-- 2. COMPLETENESS ANALYSIS (Missing Values)
-- =====================================================

-- Column-level completeness metrics
-- NOTE: Replace column names based on your table structure
SELECT
    column_name,
    total_count,
    non_null_count,
    null_count,
    null_percentage,
    CASE
        WHEN null_percentage = 0 THEN 100
        WHEN null_percentage <= 5 THEN 95
        WHEN null_percentage <= 10 THEN 85
        WHEN null_percentage <= 20 THEN 70
        WHEN null_percentage <= 50 THEN 50
        ELSE 25
    END as completeness_score,
    CASE
        WHEN null_percentage = 0 THEN 'EXCELLENT - Complete'
        WHEN null_percentage <= 5 THEN 'GOOD - Highly Complete'
        WHEN null_percentage <= 20 THEN 'FAIR - Moderately Complete'
        ELSE 'POOR - Significant Missing Data'
    END as completeness_rating
FROM (
    SELECT
        'column_1' as column_name,  -- Replace with actual column name
        COUNT(*) as total_count,
        COUNT({column_1}) as non_null_count,
        COUNT(*) - COUNT({column_1}) as null_count,
        CAST((COUNT(*) - COUNT({column_1})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as null_percentage
    FROM {database}.{table_name}

    UNION ALL

    SELECT
        'column_2' as column_name,  -- Repeat for each column
        COUNT(*) as total_count,
        COUNT({column_2}) as non_null_count,
        COUNT(*) - COUNT({column_2}) as null_count,
        CAST((COUNT(*) - COUNT({column_2})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as null_percentage
    FROM {database}.{table_name}
) AS completeness_data
ORDER BY null_percentage DESC
;

-- =====================================================
-- 3. UNIQUENESS ANALYSIS
-- =====================================================

-- Assess uniqueness and duplicate detection
SELECT
    column_name,
    total_records,
    distinct_values,
    duplicate_values,
    uniqueness_ratio,
    CASE
        WHEN uniqueness_ratio >= 95 THEN 100
        WHEN uniqueness_ratio >= 80 THEN 90
        WHEN uniqueness_ratio >= 50 THEN 70
        WHEN uniqueness_ratio >= 20 THEN 50
        ELSE 30
    END as uniqueness_score,
    CASE
        WHEN uniqueness_ratio >= 95 THEN 'EXCELLENT - Highly Unique'
        WHEN uniqueness_ratio >= 50 THEN 'GOOD - Moderate Uniqueness'
        ELSE 'POOR - Low Uniqueness'
    END as uniqueness_rating
FROM (
    SELECT
        'column_1' as column_name,
        COUNT(*) as total_records,
        COUNT(DISTINCT {column_1}) as distinct_values,
        COUNT(*) - COUNT(DISTINCT {column_1}) as duplicate_values,
        CAST(COUNT(DISTINCT {column_1}) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) as uniqueness_ratio
    FROM {database}.{table_name}
    WHERE {column_1} IS NOT NULL

    UNION ALL

    SELECT
        'column_2' as column_name,
        COUNT(*) as total_records,
        COUNT(DISTINCT {column_2}) as distinct_values,
        COUNT(*) - COUNT(DISTINCT {column_2}) as duplicate_values,
        CAST(COUNT(DISTINCT {column_2}) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) as uniqueness_ratio
    FROM {database}.{table_name}
    WHERE {column_2} IS NOT NULL
) AS uniqueness_data
ORDER BY uniqueness_ratio DESC
;

-- =====================================================
-- 4. VALIDITY ANALYSIS (Data Type Conformance)
-- =====================================================

-- Numeric column validity (range checks)
SELECT
    '{numeric_column}' as column_name,
    COUNT(*) as total_values,
    COUNT({numeric_column}) as non_null_values,
    SUM(CASE WHEN {numeric_column} < {expected_min} OR {numeric_column} > {expected_max} THEN 1 ELSE 0 END) as out_of_range_count,
    CAST(SUM(CASE WHEN {numeric_column} < {expected_min} OR {numeric_column} > {expected_max} THEN 1 ELSE 0 END) * 100.0 /
         NULLIF(COUNT({numeric_column}), 0) AS DECIMAL(5,2)) as invalid_percentage,
    CASE
        WHEN SUM(CASE WHEN {numeric_column} < {expected_min} OR {numeric_column} > {expected_max} THEN 1 ELSE 0 END) = 0
        THEN 100
        WHEN CAST(SUM(CASE WHEN {numeric_column} < {expected_min} OR {numeric_column} > {expected_max} THEN 1 ELSE 0 END) * 100.0 /
                  NULLIF(COUNT({numeric_column}), 0) AS DECIMAL(5,2)) < 5
        THEN 90
        ELSE 60
    END as validity_score,
    CASE
        WHEN SUM(CASE WHEN {numeric_column} < {expected_min} OR {numeric_column} > {expected_max} THEN 1 ELSE 0 END) = 0
        THEN 'EXCELLENT - All Valid'
        WHEN CAST(SUM(CASE WHEN {numeric_column} < {expected_min} OR {numeric_column} > {expected_max} THEN 1 ELSE 0 END) * 100.0 /
                  NULLIF(COUNT({numeric_column}), 0) AS DECIMAL(5,2)) < 10
        THEN 'GOOD - Mostly Valid'
        ELSE 'POOR - Many Invalid Values'
    END as validity_rating
FROM {database}.{table_name}
;

-- =====================================================
-- 5. CONSISTENCY ANALYSIS
-- =====================================================

-- Check for data format consistency (example for string columns)
SELECT
    '{text_column}' as column_name,
    COUNT(*) as total_values,
    COUNT(DISTINCT LENGTH({text_column})) as distinct_length_count,
    MIN(LENGTH({text_column})) as min_length,
    MAX(LENGTH({text_column})) as max_length,
    STDDEV(LENGTH({text_column})) as length_std_dev,
    -- Check for leading/trailing spaces
    SUM(CASE WHEN TRIM({text_column}) <> {text_column} THEN 1 ELSE 0 END) as whitespace_issue_count,
    -- Check for mixed case inconsistency (if applicable)
    SUM(CASE WHEN {text_column} <> UPPER({text_column}) AND {text_column} <> LOWER({text_column}) THEN 1 ELSE 0 END) as mixed_case_count,
    CASE
        WHEN STDDEV(LENGTH({text_column})) / NULLIF(AVG(LENGTH({text_column})), 0) < 0.2
        THEN 'HIGH - Consistent Format'
        WHEN STDDEV(LENGTH({text_column})) / NULLIF(AVG(LENGTH({text_column})), 0) < 0.5
        THEN 'MODERATE - Some Variation'
        ELSE 'LOW - Inconsistent Format'
    END as format_consistency
FROM {database}.{table_name}
WHERE {text_column} IS NOT NULL
;

-- =====================================================
-- 6. DUPLICATE RECORD DETECTION
-- =====================================================

-- Find duplicate rows (considering all or key columns)
WITH duplicate_check AS (
    SELECT
        {id_column},  -- Or all columns: *
        COUNT(*) as occurrence_count
    FROM {database}.{table_name}
    GROUP BY {id_column}  -- Or all columns: ALL
    HAVING COUNT(*) > 1
)
SELECT
    '{database}.{table_name}' as table_name,
    COUNT(*) as duplicate_key_count,
    SUM(occurrence_count) as total_duplicate_rows,
    (SELECT COUNT(*) FROM {database}.{table_name}) as total_rows,
    CAST(SUM(occurrence_count) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name}) AS DECIMAL(5,2)) as duplicate_percentage,
    CASE
        WHEN COUNT(*) = 0 THEN 100
        WHEN CAST(SUM(occurrence_count) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name}) AS DECIMAL(5,2)) < 1 THEN 95
        WHEN CAST(SUM(occurrence_count) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name}) AS DECIMAL(5,2)) < 5 THEN 80
        ELSE 50
    END as uniqueness_score
FROM duplicate_check
;

-- =====================================================
-- 7. REFERENTIAL INTEGRITY (If Applicable)
-- =====================================================

-- Check foreign key relationships (example)
SELECT
    '{foreign_key_column}' as column_name,
    COUNT(*) as total_fk_values,
    COUNT(DISTINCT {foreign_key_column}) as distinct_fk_values,
    SUM(CASE WHEN p.{primary_key_column} IS NULL THEN 1 ELSE 0 END) as orphaned_records,
    CAST(SUM(CASE WHEN p.{primary_key_column} IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as orphan_percentage,
    CASE
        WHEN SUM(CASE WHEN p.{primary_key_column} IS NULL THEN 1 ELSE 0 END) = 0 THEN 100
        WHEN CAST(SUM(CASE WHEN p.{primary_key_column} IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) < 1 THEN 90
        ELSE 60
    END as integrity_score
FROM {database}.{child_table} c
LEFT JOIN {database}.{parent_table} p
    ON c.{foreign_key_column} = p.{primary_key_column}
WHERE c.{foreign_key_column} IS NOT NULL
;

-- =====================================================
-- 8. TEMPORAL CONSISTENCY (For Date/Time Columns)
-- =====================================================

-- Check date/time column validity
SELECT
    '{date_column}' as column_name,
    COUNT(*) as total_values,
    MIN({date_column}) as earliest_date,
    MAX({date_column}) as latest_date,
    MAX({date_column}) - MIN({date_column}) as date_range_days,
    -- Future date check
    SUM(CASE WHEN {date_column} > CURRENT_DATE THEN 1 ELSE 0 END) as future_date_count,
    -- Very old date check (e.g., before 1900)
    SUM(CASE WHEN {date_column} < DATE '1900-01-01' THEN 1 ELSE 0 END) as ancient_date_count,
    -- Null check
    COUNT(*) - COUNT({date_column}) as null_count,
    CASE
        WHEN SUM(CASE WHEN {date_column} > CURRENT_DATE OR {date_column} < DATE '1900-01-01' THEN 1 ELSE 0 END) = 0
        THEN 100
        WHEN CAST(SUM(CASE WHEN {date_column} > CURRENT_DATE OR {date_column} < DATE '1900-01-01' THEN 1 ELSE 0 END) * 100.0 /
                  NULLIF(COUNT({date_column}), 0) AS DECIMAL(5,2)) < 5
        THEN 85
        ELSE 60
    END as temporal_validity_score
FROM {database}.{table_name}
;

-- =====================================================
-- 9. COLUMN-LEVEL QUALITY SCORECARD
-- =====================================================

-- Comprehensive quality score per column
CREATE MULTISET TABLE {database}.{table_name}_quality_scorecard AS (
    SELECT
        column_name,
        completeness_score,
        uniqueness_score,
        validity_score,
        consistency_score,
        -- Overall quality score (weighted average)
        CAST((completeness_score * 0.30 +
              uniqueness_score * 0.25 +
              validity_score * 0.25 +
              consistency_score * 0.20) AS DECIMAL(5,2)) as overall_quality_score,
        CASE
            WHEN CAST((completeness_score * 0.30 +
                       uniqueness_score * 0.25 +
                       validity_score * 0.25 +
                       consistency_score * 0.20) AS DECIMAL(5,2)) >= 90 THEN 'EXCELLENT'
            WHEN CAST((completeness_score * 0.30 +
                       uniqueness_score * 0.25 +
                       validity_score * 0.25 +
                       consistency_score * 0.20) AS DECIMAL(5,2)) >= 70 THEN 'GOOD'
            WHEN CAST((completeness_score * 0.30 +
                       uniqueness_score * 0.25 +
                       validity_score * 0.25 +
                       consistency_score * 0.20) AS DECIMAL(5,2)) >= 50 THEN 'FAIR'
            ELSE 'POOR'
        END as quality_grade,
        CURRENT_TIMESTAMP as assessed_at
    FROM (
        -- Example data - replace with actual quality metrics from previous queries
        SELECT
            'column_1' as column_name,
            95.0 as completeness_score,
            80.0 as uniqueness_score,
            90.0 as validity_score,
            85.0 as consistency_score

        UNION ALL

        SELECT
            'column_2' as column_name,
            70.0 as completeness_score,
            60.0 as uniqueness_score,
            75.0 as validity_score,
            65.0 as consistency_score
    ) AS quality_metrics
) WITH DATA PRIMARY INDEX (column_name)
;

-- View quality scorecard
SELECT * FROM {database}.{table_name}_quality_scorecard
ORDER BY overall_quality_score DESC;

-- =====================================================
-- 10. TABLE-LEVEL QUALITY SUMMARY
-- =====================================================

-- Overall table quality assessment
WITH column_scores AS (
    SELECT
        AVG(completeness_score) as avg_completeness,
        AVG(uniqueness_score) as avg_uniqueness,
        AVG(validity_score) as avg_validity,
        AVG(consistency_score) as avg_consistency,
        AVG(overall_quality_score) as avg_overall_quality,
        MIN(overall_quality_score) as min_column_quality,
        MAX(overall_quality_score) as max_column_quality,
        STDDEV(overall_quality_score) as quality_std_dev,
        COUNT(*) as total_columns_assessed,
        SUM(CASE WHEN overall_quality_score >= 90 THEN 1 ELSE 0 END) as excellent_columns,
        SUM(CASE WHEN overall_quality_score >= 70 AND overall_quality_score < 90 THEN 1 ELSE 0 END) as good_columns,
        SUM(CASE WHEN overall_quality_score >= 50 AND overall_quality_score < 70 THEN 1 ELSE 0 END) as fair_columns,
        SUM(CASE WHEN overall_quality_score < 50 THEN 1 ELSE 0 END) as poor_columns
    FROM {database}.{table_name}_quality_scorecard
)
SELECT
    '{database}.{table_name}' as table_name,
    total_columns_assessed,
    CAST(avg_completeness AS DECIMAL(5,2)) as avg_completeness_score,
    CAST(avg_uniqueness AS DECIMAL(5,2)) as avg_uniqueness_score,
    CAST(avg_validity AS DECIMAL(5,2)) as avg_validity_score,
    CAST(avg_consistency AS DECIMAL(5,2)) as avg_consistency_score,
    CAST(avg_overall_quality AS DECIMAL(5,2)) as overall_table_quality_score,
    CAST(min_column_quality AS DECIMAL(5,2)) as worst_column_score,
    CAST(max_column_quality AS DECIMAL(5,2)) as best_column_score,
    excellent_columns,
    good_columns,
    fair_columns,
    poor_columns,
    CASE
        WHEN avg_overall_quality >= 90 THEN 'EXCELLENT - High Quality Data'
        WHEN avg_overall_quality >= 70 THEN 'GOOD - Acceptable Quality'
        WHEN avg_overall_quality >= 50 THEN 'FAIR - Needs Improvement'
        ELSE 'POOR - Significant Issues'
    END as table_quality_assessment,
    CURRENT_TIMESTAMP as assessment_date
FROM column_scores
;

-- =====================================================
-- 11. DATA QUALITY ISSUES SUMMARY
-- =====================================================

-- Identify and prioritize data quality issues
SELECT
    column_name,
    overall_quality_score,
    CASE
        WHEN completeness_score < 80 THEN 'Missing Values'
        ELSE NULL
    END as issue_1,
    CASE
        WHEN uniqueness_score < 70 THEN 'Low Uniqueness/Duplicates'
        ELSE NULL
    END as issue_2,
    CASE
        WHEN validity_score < 80 THEN 'Invalid Values/Out of Range'
        ELSE NULL
    END as issue_3,
    CASE
        WHEN consistency_score < 70 THEN 'Format Inconsistency'
        ELSE NULL
    END as issue_4,
    CASE
        WHEN overall_quality_score < 50 THEN 'CRITICAL - Immediate Action Required'
        WHEN overall_quality_score < 70 THEN 'HIGH - Should Address Soon'
        WHEN overall_quality_score < 85 THEN 'MEDIUM - Monitor'
        ELSE 'LOW - Acceptable'
    END as priority
FROM {database}.{table_name}_quality_scorecard
WHERE overall_quality_score < 85
ORDER BY overall_quality_score ASC
;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {table_name} - Your table name
--    {column_1}, {column_2}, etc. - Actual column names
--    {numeric_column}, {text_column}, {date_column} - Column names by type
--    {id_column} - Primary key or unique identifier
--    {expected_min}, {expected_max} - Valid range bounds for numeric columns
--
-- 2. Execute sections sequentially to build quality metrics
--
-- 3. Section 9 creates a consolidated quality scorecard table
--
-- 4. Use results to:
--    - Identify data quality issues
--    - Prioritize data cleansing efforts
--    - Track quality improvements over time
--    - Generate quality reports for stakeholders
--
-- =====================================================
