-- =====================================================
-- TD_StationarityTest - Parameter Optimization
-- =====================================================
-- Purpose: Optimize parameters for stationarity testing
-- Function: TD_StationarityTest with parameter testing
-- Framework: Teradata Unbounded Array Framework (UAF)
-- =====================================================

-- PREREQUISITE: Run uaf_data_preparation.sql first

-- This script tests multiple parameter configurations to find optimal settings
-- for your specific time series data and analytical objectives

-- INSTRUCTIONS:
-- 1. Replace {USER_DATABASE} with your database name
-- 2. Adjust parameter ranges based on your data characteristics
-- 3. Review comparison results to select best configuration
-- 4. Use selected parameters in main workflow

-- ============================================================================
-- STEP 1: Test Parameter Configuration 1
-- ============================================================================

-- Configuration 1: Default/Conservative parameters
DROP TABLE IF EXISTS {USER_DATABASE}.stationarity_test_config1;
CREATE MULTISET TABLE {USER_DATABASE}.stationarity_test_config1 AS (
    SELECT * FROM TD_StationarityTest (
        ON {USER_DATABASE}.uaf_stationarity_test_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        -- TestType: Configure based on your requirements
        -- MaxLag: Configure based on your requirements
        -- Configuration 1 specific values
    ) AS dt
) WITH DATA;

-- ============================================================================
-- STEP 2: Test Parameter Configuration 2
-- ============================================================================

-- Configuration 2: Alternative parameters
DROP TABLE IF EXISTS {USER_DATABASE}.stationarity_test_config2;
CREATE MULTISET TABLE {USER_DATABASE}.stationarity_test_config2 AS (
    SELECT * FROM TD_StationarityTest (
        ON {USER_DATABASE}.uaf_stationarity_test_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        -- TestType: Configure based on your requirements
        -- MaxLag: Configure based on your requirements
        -- Configuration 2 specific values
    ) AS dt
) WITH DATA;

-- ============================================================================
-- STEP 3: Test Parameter Configuration 3
-- ============================================================================

-- Configuration 3: Optimized parameters
DROP TABLE IF EXISTS {USER_DATABASE}.stationarity_test_config3;
CREATE MULTISET TABLE {USER_DATABASE}.stationarity_test_config3 AS (
    SELECT * FROM TD_StationarityTest (
        ON {USER_DATABASE}.uaf_stationarity_test_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        -- TestType: Configure based on your requirements
        -- MaxLag: Configure based on your requirements
        -- Configuration 3 specific values
    ) AS dt
) WITH DATA;

-- ============================================================================
-- STEP 4: Compare Parameter Configurations
-- ============================================================================

-- Compare results across configurations
SELECT
    'Configuration 1' as config_name,
    COUNT(*) as result_count,
    MIN(result_value) as min_value,
    MAX(result_value) as max_value,
    AVG(result_value) as avg_value,
    STDDEV(result_value) as std_dev
FROM {USER_DATABASE}.stationarity_test_config1

UNION ALL

SELECT
    'Configuration 2',
    COUNT(*),
    MIN(result_value),
    MAX(result_value),
    AVG(result_value),
    STDDEV(result_value)
FROM {USER_DATABASE}.stationarity_test_config2

UNION ALL

SELECT
    'Configuration 3',
    COUNT(*),
    MIN(result_value),
    MAX(result_value),
    AVG(result_value),
    STDDEV(result_value)
FROM {USER_DATABASE}.stationarity_test_config3

ORDER BY config_name;

-- ============================================================================
-- STEP 5: Quality Metrics Comparison
-- ============================================================================

-- Evaluate configuration quality
SELECT
    'Quality Comparison' as metric_category,
    (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_config1 WHERE result_value IS NOT NULL) as config1_valid_results,
    (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_config2 WHERE result_value IS NOT NULL) as config2_valid_results,
    (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_config3 WHERE result_value IS NOT NULL) as config3_valid_results,
    CASE
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_config1 WHERE result_value IS NOT NULL) >=
             (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_config2 WHERE result_value IS NOT NULL) AND
             (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_config1 WHERE result_value IS NOT NULL) >=
             (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_config3 WHERE result_value IS NOT NULL)
        THEN 'Configuration 1'
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_config2 WHERE result_value IS NOT NULL) >=
             (SELECT COUNT(*) FROM {USER_DATABASE}.stationarity_test_config3 WHERE result_value IS NOT NULL)
        THEN 'Configuration 2'
        ELSE 'Configuration 3'
    END as recommended_config;

-- ============================================================================
-- STEP 6: Parameter Selection Guidance
-- ============================================================================

-- Selection criteria and recommendations
SELECT
    'Parameter Optimization Guidance' as guideline_type,
    'Choose configuration with best balance of coverage and stability' as criterion,
    'Consider business requirements and computational resources' as consideration,
    'Test selected parameters on validation dataset' as validation_step;

-- ============================================================================
-- STEP 7: Best Configuration Summary
-- ============================================================================

-- Identify and summarize best configuration
SELECT
    'RECOMMENDED CONFIGURATION' as selection_result,
    'Review comparison results above to select optimal parameters' as guidance,
    'Use selected parameters in td_stationarity_test_workflow.sql' as next_step;

-- ============================================================================
-- CLEANUP (Optional)
-- ============================================================================
/*
-- Uncomment to remove test configuration tables after selection
DROP TABLE {USER_DATABASE}.stationarity_test_config1;
DROP TABLE {USER_DATABASE}.stationarity_test_config2;
DROP TABLE {USER_DATABASE}.stationarity_test_config3;
*/

-- ============================================================================
-- PARAMETER OPTIMIZATION CHECKLIST:
-- ============================================================================
/*
□ Multiple parameter configurations tested
□ Results compared across configurations
□ Quality metrics evaluated
□ Best configuration identified
□ Parameters documented for workflow
□ Ready to proceed with optimized settings
*/
-- =====================================================
