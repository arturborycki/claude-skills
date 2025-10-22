-- UAF Pipeline Template for TD_CROSS_VALIDATION
-- Multi-function workflow for CROSS_VALIDATION in model preparation pipeline

-- ============================================================================
-- PIPELINE: Data Prep → Model Training → Cross-Validation → Performance Assessment
-- ============================================================================

-- Stage 1: Data Preparation
DROP TABLE IF EXISTS td_cross_validation_pipeline_input;
CREATE MULTISET TABLE td_cross_validation_pipeline_input AS (
    SELECT * FROM TD_DATA_PREPARATION (
        ON {YOUR_SOURCE_TABLE}
        USING TimeColumn ('{TIME_COL}') ValueColumn ('{VALUE_COL}')
    ) AS dt
) WITH DATA;

-- Stage 2: Execute TD_CROSS_VALIDATION with optimal parameters
DROP TABLE IF EXISTS td_cross_validation_pipeline_results;
CREATE MULTISET TABLE td_cross_validation_pipeline_results AS (
    SELECT * FROM TD_CROSS_VALIDATION (
        ON td_cross_validation_pipeline_input
        USING
        -- Apply optimal parameters from parameter_optimization.sql
        -- Refer to optimal_config table for recommended settings
    ) AS dt
) WITH DATA;

-- Stage 3: Results Analysis
SELECT
    'TD_CROSS_VALIDATION Pipeline Results' as ReportType,
    COUNT(*) as TotalRecords,
    CURRENT_TIMESTAMP as CompletionTime
FROM td_cross_validation_pipeline_results;

-- Stage 4: Export results for downstream processing
SELECT * FROM td_cross_validation_pipeline_results
ORDER BY time_index;

/*
TD_CROSS_VALIDATION PIPELINE INTEGRATION:

UPSTREAM DEPENDENCIES:
- TD_DATA_PREPARATION: Clean, validated time series data
- Parameter optimization: Optimal function parameters

DOWNSTREAM CONSUMERS:
- Performance monitoring: Track function execution
- Result interpretation: Analyze outputs
- Production deployment: Apply to live data

PIPELINE BEST PRACTICES:
□ Apply optimal parameters from parameter_optimization.sql
□ Validate input data quality before processing
□ Log pipeline execution metadata
□ Monitor performance metrics
□ Handle errors gracefully
□ Document configuration choices

TYPICAL UAF WORKFLOW:
1. TD_DATA_PREPARATION → Clean data
2. TD_PARAMETER_ESTIMATION → Estimate parameters
3. TD_MODEL_SELECTION → Choose best model
4. TD_CROSS_VALIDATION → Validate model
5. TD_SMOOTHING → Clean residuals/signals (if needed)
6. TD_PORTMAN → Diagnostic testing

NEXT STEPS:
- Customize for your specific use case
- Integrate with other UAF functions
- Add domain-specific validations
- Implement automated scheduling
- Monitor pipeline health
*/
