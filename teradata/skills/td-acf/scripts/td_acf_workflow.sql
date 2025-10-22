-- =====================================================
-- TD_ACF - Complete UAF Workflow
-- =====================================================
-- Purpose: Auto-Correlation Function using Teradata UAF
-- Function: TD_ACF
-- Framework: Teradata Unbounded Array Framework (UAF)
-- =====================================================

-- PREREQUISITE: Run uaf_data_preparation.sql first

-- INSTRUCTIONS:
-- 1. Replace {USER_DATABASE} with your database name
-- 2. Configure function-specific parameters based on data analysis
-- 3. Adjust parameters based on your analytical requirements

-- ============================================================================
-- STEP 1: Execute TD_ACF for Analysis
-- ============================================================================

-- Execute UAF function with optimal parameters
DROP TABLE IF EXISTS {USER_DATABASE}.acf_results;
CREATE MULTISET TABLE {USER_DATABASE}.acf_results AS (
    SELECT * FROM TD_ACF (
        ON {USER_DATABASE}.uaf_acf_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        -- Function-specific parameters
        -- Configure based on your data analysis and requirements
        -- Refer to Teradata UAF documentation for TD_ACF parameters
    ) AS dt
) WITH DATA;

-- ============================================================================
-- STEP 2: Review Analysis Results
-- ============================================================================

-- View primary results
SELECT TOP 100 *
FROM {USER_DATABASE}.acf_results
ORDER BY time_index;

-- ============================================================================
-- STEP 3: Results Summary Statistics
-- ============================================================================

-- Calculate result metrics
SELECT
    'Analysis Summary' as metric_category,
    COUNT(*) as result_rows,
    MIN(time_index) as start_time,
    MAX(time_index) as end_time,
    CURRENT_TIMESTAMP as completion_time
FROM {USER_DATABASE}.acf_results;

-- ============================================================================
-- STEP 4: Data Quality and Validation
-- ============================================================================

-- Validate results quality
SELECT
    'Data Quality Check' as check_type,
    COUNT(*) as total_results,
    SUM(CASE WHEN result_value IS NULL THEN 1 ELSE 0 END) as null_results,
    CASE
        WHEN SUM(CASE WHEN result_value IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'All results generated successfully'
        ELSE 'Some results missing - review input data'
    END as quality_status
FROM {USER_DATABASE}.acf_results;

-- ============================================================================
-- STEP 5: Export Results for Analysis
-- ============================================================================

-- Export results for further analysis or visualization
SELECT
    time_index,
    result_value,
    sequence_id
FROM {USER_DATABASE}.acf_results
ORDER BY sequence_id;

-- ============================================================================
-- STEP 6: Analysis Completion Summary
-- ============================================================================

-- Comprehensive analysis summary
SELECT
    'TD_ACF Analysis Complete' as status,
    (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_acf_input) as input_observations,
    (SELECT COUNT(*) FROM {USER_DATABASE}.acf_results) as output_results,
    CURRENT_TIMESTAMP as analysis_timestamp;

-- Next Steps Recommendations
SELECT
    'Next Steps' as recommendation_type,
    'Results generated successfully - proceed to result_interpretation.sql for detailed analysis' as recommendation;

-- ============================================================================
-- CLEANUP (Optional - comment out to preserve results)
-- ============================================================================
-- DROP TABLE {USER_DATABASE}.acf_results;

-- ============================================================================
-- UAF TD_ACF WORKFLOW CHECKLIST:
-- ============================================================================
/*
□ Data preparation completed (uaf_data_preparation.sql)
□ Function parameters configured appropriately
□ UAF function executed successfully
□ Results generated and validated
□ Data quality checks passed
□ Results exported for analysis
□ Ready for interpretation and visualization
*/
-- =====================================================
