-- =====================================================
-- TD_StationarityTest - Result Interpretation
-- =====================================================
-- Purpose: Interpret and visualize stationarity testing results
-- Function: TD_StationarityTest diagnostic analysis
-- Framework: Teradata Unbounded Array Framework (UAF)
-- =====================================================

-- PREREQUISITE: Run td_stationarity_test_workflow.sql first

-- INSTRUCTIONS:
-- Replace {USER_DATABASE} with your database name

-- ============================================================================
-- STEP 1: Results Overview and Summary Statistics
-- ============================================================================

-- Comprehensive results summary
SELECT
    'Results Overview' as analysis_section,
    COUNT(*) as total_results,
    MIN(time_index) as start_time,
    MAX(time_index) as end_time,
    CAST(MIN(result_value) AS DECIMAL(12,4)) as min_result,
    CAST(MAX(result_value) AS DECIMAL(12,4)) as max_result,
    CAST(AVG(result_value) AS DECIMAL(12,4)) as avg_result,
    CAST(STDDEV(result_value) AS DECIMAL(12,4)) as std_dev_result
FROM {USER_DATABASE}.stationarity_test_results;

-- ============================================================================
-- STEP 2: Detailed Results Analysis
-- ============================================================================

-- Analyze result distribution
WITH result_stats AS (
    SELECT
        result_value,
        CAST(result_value AS DECIMAL(12,4)) as value_decimal,
        CASE
            WHEN result_value > AVG(result_value) OVER () + 2 * STDDEV(result_value) OVER () THEN 'High outlier'
            WHEN result_value < AVG(result_value) OVER () - 2 * STDDEV(result_value) OVER () THEN 'Low outlier'
            WHEN result_value > AVG(result_value) OVER () + STDDEV(result_value) OVER () THEN 'Above average'
            WHEN result_value < AVG(result_value) OVER () - STDDEV(result_value) OVER () THEN 'Below average'
            ELSE 'Normal range'
        END as distribution_category
    FROM {USER_DATABASE}.stationarity_test_results
)
SELECT
    distribution_category,
    COUNT(*) as count,
    CAST(MIN(value_decimal) AS DECIMAL(12,4)) as min_value,
    CAST(MAX(value_decimal) AS DECIMAL(12,4)) as max_value,
    CAST(AVG(value_decimal) AS DECIMAL(12,4)) as avg_value,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(8,2)) as percentage
FROM result_stats
GROUP BY distribution_category
ORDER BY distribution_category;

-- ============================================================================
-- STEP 3: Time-Based Pattern Analysis
-- ============================================================================

-- Analyze temporal patterns in results
WITH time_buckets AS (
    SELECT
        time_index,
        result_value,
        NTILE(10) OVER (ORDER BY time_index) as time_decile
    FROM {USER_DATABASE}.stationarity_test_results
)
SELECT
    time_decile,
    COUNT(*) as observations,
    CAST(MIN(result_value) AS DECIMAL(12,4)) as min_value,
    CAST(MAX(result_value) AS DECIMAL(12,4)) as max_value,
    CAST(AVG(result_value) AS DECIMAL(12,4)) as avg_value,
    CAST(STDDEV(result_value) AS DECIMAL(12,4)) as std_dev
FROM time_buckets
GROUP BY time_decile
ORDER BY time_decile;

-- ============================================================================
-- STEP 4: Quality Assessment
-- ============================================================================

-- Assess result quality and completeness
SELECT
    'Quality Assessment' as check_category,
    COUNT(*) as total_results,
    SUM(CASE WHEN result_value IS NULL THEN 1 ELSE 0 END) as null_results,
    SUM(CASE WHEN result_value IS NOT NULL THEN 1 ELSE 0 END) as valid_results,
    CAST(SUM(CASE WHEN result_value IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(8,2)) as completeness_pct,
    CASE
        WHEN SUM(CASE WHEN result_value IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 95
        THEN 'Excellent - High completeness (>=95%)'
        WHEN SUM(CASE WHEN result_value IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 80
        THEN 'Good - Acceptable completeness (>=80%)'
        ELSE 'Warning - Low completeness (<80%)'
    END as quality_assessment
FROM {USER_DATABASE}.stationarity_test_results;

-- ============================================================================
-- STEP 5: Comparative Analysis with Input Data
-- ============================================================================

-- Compare results with original input data
SELECT
    'Input vs Results Comparison' as comparison_type,
    (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_stationarity_test_input) as input_observations,
    (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_results) as result_observations,
    CAST((SELECT AVG(series_value) FROM {USER_DATABASE}.uaf_stationarity_test_input) AS DECIMAL(12,4)) as input_avg,
    CAST((SELECT AVG(result_value) FROM {USER_DATABASE}.stationarity_test_results) AS DECIMAL(12,4)) as result_avg,
    CAST((SELECT STDDEV(series_value) FROM {USER_DATABASE}.uaf_stationarity_test_input) AS DECIMAL(12,4)) as input_std,
    CAST((SELECT STDDEV(result_value) FROM {USER_DATABASE}.stationarity_test_results) AS DECIMAL(12,4)) as result_std;

-- ============================================================================
-- STEP 6: Business Interpretation
-- ============================================================================

-- Business-focused interpretation
SELECT
    'Business Interpretation' as section,
    'Result Quality' as aspect,
    CASE
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_results WHERE result_value IS NOT NULL) >=
             (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_results) * 0.95
        THEN 'High quality results - suitable for business decision making'
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_results WHERE result_value IS NOT NULL) >=
             (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_results) * 0.80
        THEN 'Acceptable quality results - use with appropriate caution'
        ELSE 'Results need review - investigate data quality issues'
    END as interpretation

UNION ALL

SELECT
    'Business Interpretation',
    'Recommended Actions',
    CASE
        WHEN (SELECT STDDEV(result_value) FROM {USER_DATABASE}.stationarity_test_results) /
             NULLIF((SELECT AVG(result_value) FROM {USER_DATABASE}.stationarity_test_results), 0) < 0.2
        THEN 'Results show low variability - patterns are consistent'
        WHEN (SELECT STDDEV(result_value) FROM {USER_DATABASE}.stationarity_test_results) /
             NULLIF((SELECT AVG(result_value) FROM {USER_DATABASE}.stationarity_test_results), 0) < 0.5
        THEN 'Results show moderate variability - monitor for changes'
        ELSE 'Results show high variability - investigate underlying causes'
    END

UNION ALL

SELECT
    'Business Interpretation',
    'Next Steps',
    'Proceed to uaf_pipeline_template.sql for integrated analysis' as interpretation;

-- ============================================================================
-- STEP 7: Key Findings Summary
-- ============================================================================

-- Summarize key findings
SELECT
    'Key Findings Summary' as summary_section,
    COUNT(*) as total_results_analyzed,
    CAST(AVG(result_value) AS DECIMAL(12,4)) as average_result,
    CAST(STDDEV(result_value) AS DECIMAL(12,4)) as result_variability,
    CAST(MIN(result_value) AS DECIMAL(12,4)) as minimum_result,
    CAST(MAX(result_value) AS DECIMAL(12,4)) as maximum_result,
    CURRENT_TIMESTAMP as analysis_timestamp
FROM {USER_DATABASE}.stationarity_test_results;

-- ============================================================================
-- STEP 8: Visualization Data Export
-- ============================================================================

-- Export results for external visualization tools
SELECT
    time_index,
    sequence_id,
    CAST(result_value AS DECIMAL(12,4)) as result_value,
    CASE
        WHEN result_value > AVG(result_value) OVER () THEN 'Above Average'
        ELSE 'Below Average'
    END as category
FROM {USER_DATABASE}.stationarity_test_results
ORDER BY time_index;

-- ============================================================================
-- STEP 9: Recommendations and Insights
-- ============================================================================

-- Generate actionable recommendations
SELECT
    'Recommendations' as category,
    'Data Quality' as subcategory,
    CASE
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_results WHERE result_value IS NULL) = 0
        THEN 'No missing values - data quality is excellent'
        ELSE 'Review and address missing values in results'
    END as recommendation

UNION ALL

SELECT
    'Recommendations',
    'Further Analysis',
    'Consider combining with complementary UAF functions for deeper insights'

UNION ALL

SELECT
    'Recommendations',
    'Production Deployment',
    CASE
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_results WHERE result_value IS NOT NULL) >=
             (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_results) * 0.90
        THEN 'Results are production-ready - proceed with confidence'
        ELSE 'Refine parameters and retest before production deployment'
    END;

-- ============================================================================
-- RESULT INTERPRETATION CHECKLIST:
-- ============================================================================
/*
□ Results summary statistics reviewed
□ Distribution analysis completed
□ Temporal patterns analyzed
□ Quality assessment performed
□ Comparison with input data conducted
□ Business interpretation provided
□ Key findings summarized
□ Visualization data exported
□ Recommendations generated
*/
-- =====================================================
