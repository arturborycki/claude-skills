-- =====================================================
-- TD_ARIMAESTIMATE - Parameter Optimization
-- =====================================================
-- Purpose: Optimize ARIMA (p,d,q) and seasonal parameters
-- Function: TD_ARIMAESTIMATE with grid search
-- Framework: Teradata Unbounded Array Framework (UAF)
-- =====================================================

-- PREREQUISITE: Run uaf_data_preparation.sql first

-- This script tests multiple ARIMA configurations to find optimal parameters
-- using AIC and BIC for model selection

-- INSTRUCTIONS:
-- 1. Replace {USER_DATABASE} with your database name
-- 2. Adjust parameter ranges based on ACF/PACF analysis
-- 3. Review model comparison results
-- 4. Select best model based on AIC/BIC

-- ============================================================================
-- STEP 1: Test Non-Seasonal ARIMA Models
-- ============================================================================

-- ARIMA(0,1,1) - Simple MA model with first-order differencing
DROP TABLE IF EXISTS {USER_DATABASE}.arima_011_estimate;
CREATE MULTISET TABLE {USER_DATABASE}.arima_011_estimate AS (
    SELECT * FROM TD_ARIMAESTIMATE (
        ON {USER_DATABASE}.uaf_arimaestimate_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        Orders('0,1,1')
        FitMethod('ML')
        IncludeFitStats('true')
    ) AS dt
) WITH DATA;

-- ARIMA(1,1,0) - Simple AR model with first-order differencing
DROP TABLE IF EXISTS {USER_DATABASE}.arima_110_estimate;
CREATE MULTISET TABLE {USER_DATABASE}.arima_110_estimate AS (
    SELECT * FROM TD_ARIMAESTIMATE (
        ON {USER_DATABASE}.uaf_arimaestimate_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        Orders('1,1,0')
        FitMethod('ML')
        IncludeFitStats('true')
    ) AS dt
) WITH DATA;

-- ARIMA(1,1,1) - Mixed ARMA model with first-order differencing
DROP TABLE IF EXISTS {USER_DATABASE}.arima_111_estimate;
CREATE MULTISET TABLE {USER_DATABASE}.arima_111_estimate AS (
    SELECT * FROM TD_ARIMAESTIMATE (
        ON {USER_DATABASE}.uaf_arimaestimate_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        Orders('1,1,1')
        FitMethod('ML')
        IncludeFitStats('true')
    ) AS dt
) WITH DATA;

-- ARIMA(2,1,1) - Higher order AR component
DROP TABLE IF EXISTS {USER_DATABASE}.arima_211_estimate;
CREATE MULTISET TABLE {USER_DATABASE}.arima_211_estimate AS (
    SELECT * FROM TD_ARIMAESTIMATE (
        ON {USER_DATABASE}.uaf_arimaestimate_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        Orders('2,1,1')
        FitMethod('ML')
        IncludeFitStats('true')
    ) AS dt
) WITH DATA;

-- ARIMA(1,1,2) - Higher order MA component
DROP TABLE IF EXISTS {USER_DATABASE}.arima_112_estimate;
CREATE MULTISET TABLE {USER_DATABASE}.arima_112_estimate AS (
    SELECT * FROM TD_ARIMAESTIMATE (
        ON {USER_DATABASE}.uaf_arimaestimate_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        Orders('1,1,2')
        FitMethod('ML')
        IncludeFitStats('true')
    ) AS dt
) WITH DATA;

-- ARIMA(2,1,2) - Comprehensive ARMA model
DROP TABLE IF EXISTS {USER_DATABASE}.arima_212_estimate;
CREATE MULTISET TABLE {USER_DATABASE}.arima_212_estimate AS (
    SELECT * FROM TD_ARIMAESTIMATE (
        ON {USER_DATABASE}.uaf_arimaestimate_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        Orders('2,1,2')
        FitMethod('ML')
        IncludeFitStats('true')
    ) AS dt
) WITH DATA;

-- ARIMA(1,0,1) - Stationary series (no differencing)
DROP TABLE IF EXISTS {USER_DATABASE}.arima_101_estimate;
CREATE MULTISET TABLE {USER_DATABASE}.arima_101_estimate AS (
    SELECT * FROM TD_ARIMAESTIMATE (
        ON {USER_DATABASE}.uaf_arimaestimate_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        Orders('1,0,1')
        FitMethod('ML')
        IncludeFitStats('true')
    ) AS dt
) WITH DATA;

-- ARIMA(2,2,2) - Second-order differencing for strong trend
DROP TABLE IF EXISTS {USER_DATABASE}.arima_222_estimate;
CREATE MULTISET TABLE {USER_DATABASE}.arima_222_estimate AS (
    SELECT * FROM TD_ARIMAESTIMATE (
        ON {USER_DATABASE}.uaf_arimaestimate_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        Orders('2,2,2')
        FitMethod('ML')
        IncludeFitStats('true')
    ) AS dt
) WITH DATA;

-- ============================================================================
-- STEP 2: Compare Non-Seasonal Models by AIC/BIC
-- ============================================================================

-- Model comparison summary
SELECT
    'ARIMA(0,1,1)' as model_specification,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_011_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_011_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC') as BIC,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arima_011_estimate WHERE result_type = 'Coefficients') as n_parameters

UNION ALL

SELECT
    'ARIMA(1,1,0)' as model_specification,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_110_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_110_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC') as BIC,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arima_110_estimate WHERE result_type = 'Coefficients') as n_parameters

UNION ALL

SELECT
    'ARIMA(1,1,1)' as model_specification,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_111_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_111_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC') as BIC,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arima_111_estimate WHERE result_type = 'Coefficients') as n_parameters

UNION ALL

SELECT
    'ARIMA(2,1,1)' as model_specification,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_211_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_211_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC') as BIC,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arima_211_estimate WHERE result_type = 'Coefficients') as n_parameters

UNION ALL

SELECT
    'ARIMA(1,1,2)' as model_specification,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_112_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_112_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC') as BIC,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arima_112_estimate WHERE result_type = 'Coefficients') as n_parameters

UNION ALL

SELECT
    'ARIMA(2,1,2)' as model_specification,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_212_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_212_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC') as BIC,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arima_212_estimate WHERE result_type = 'Coefficients') as n_parameters

UNION ALL

SELECT
    'ARIMA(1,0,1)' as model_specification,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_101_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_101_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC') as BIC,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arima_101_estimate WHERE result_type = 'Coefficients') as n_parameters

UNION ALL

SELECT
    'ARIMA(2,2,2)' as model_specification,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_222_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_222_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC') as BIC,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arima_222_estimate WHERE result_type = 'Coefficients') as n_parameters

ORDER BY AIC;

-- ============================================================================
-- STEP 3: Test Seasonal ARIMA Models (if seasonal pattern detected)
-- ============================================================================

-- SARIMA(1,1,1)(1,1,1,12) - Monthly seasonality
DROP TABLE IF EXISTS {USER_DATABASE}.sarima_111_111_12_estimate;
CREATE MULTISET TABLE {USER_DATABASE}.sarima_111_111_12_estimate AS (
    SELECT * FROM TD_ARIMAESTIMATE (
        ON {USER_DATABASE}.uaf_arimaestimate_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        Orders('1,1,1')
        SeasonalOrders('1,1,1,12')  -- Adjust period (12) based on your data
        FitMethod('ML')
        IncludeFitStats('true')
    ) AS dt
) WITH DATA;

-- SARIMA(0,1,1)(0,1,1,12) - Seasonal MA model
DROP TABLE IF EXISTS {USER_DATABASE}.sarima_011_011_12_estimate;
CREATE MULTISET TABLE {USER_DATABASE}.sarima_011_011_12_estimate AS (
    SELECT * FROM TD_ARIMAESTIMATE (
        ON {USER_DATABASE}.uaf_arimaestimate_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        Orders('0,1,1')
        SeasonalOrders('0,1,1,12')
        FitMethod('ML')
        IncludeFitStats('true')
    ) AS dt
) WITH DATA;

-- SARIMA(1,1,1)(1,1,1,7) - Weekly seasonality
DROP TABLE IF EXISTS {USER_DATABASE}.sarima_111_111_7_estimate;
CREATE MULTISET TABLE {USER_DATABASE}.sarima_111_111_7_estimate AS (
    SELECT * FROM TD_ARIMAESTIMATE (
        ON {USER_DATABASE}.uaf_arimaestimate_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        Orders('1,1,1')
        SeasonalOrders('1,1,1,7')  -- Weekly pattern
        FitMethod('ML')
        IncludeFitStats('true')
    ) AS dt
) WITH DATA;

-- ============================================================================
-- STEP 4: Compare Seasonal Models
-- ============================================================================

SELECT
    'SARIMA(1,1,1)(1,1,1,12)' as model_specification,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.sarima_111_111_12_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.sarima_111_111_12_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC') as BIC,
    (SELECT COUNT(*) FROM {USER_DATABASE}.sarima_111_111_12_estimate WHERE result_type = 'Coefficients') as n_parameters

UNION ALL

SELECT
    'SARIMA(0,1,1)(0,1,1,12)' as model_specification,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.sarima_011_011_12_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.sarima_011_011_12_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC') as BIC,
    (SELECT COUNT(*) FROM {USER_DATABASE}.sarima_011_011_12_estimate WHERE result_type = 'Coefficients') as n_parameters

UNION ALL

SELECT
    'SARIMA(1,1,1)(1,1,1,7)' as model_specification,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.sarima_111_111_7_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.sarima_111_111_7_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC') as BIC,
    (SELECT COUNT(*) FROM {USER_DATABASE}.sarima_111_111_7_estimate WHERE result_type = 'Coefficients') as n_parameters

ORDER BY AIC;

-- ============================================================================
-- STEP 5: Model Selection Criteria and Recommendations
-- ============================================================================

-- Selection guidance
SELECT
    'Model Selection Guidance' as guideline_type,
    'AIC (Akaike Information Criterion)' as criterion,
    'Lower AIC indicates better balance of fit and complexity' as interpretation,
    'Prefer model with lowest AIC value' as recommendation

UNION ALL

SELECT
    'Model Selection Guidance' as guideline_type,
    'BIC (Bayesian Information Criterion)' as criterion,
    'Lower BIC with stronger penalty for complexity' as interpretation,
    'BIC favors simpler models - use when parsimony is important' as recommendation

UNION ALL

SELECT
    'Model Selection Guidance' as guideline_type,
    'Parameter Significance' as criterion,
    'Check coefficient t-statistics (should be >1.96 for significance)' as interpretation,
    'Avoid models with many insignificant parameters' as recommendation;

-- ============================================================================
-- STEP 6: Best Model Summary
-- ============================================================================

-- Identify best model by AIC
WITH all_models AS (
    SELECT 'ARIMA(0,1,1)' as model, (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_011_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC
    UNION ALL
    SELECT 'ARIMA(1,1,0)', (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_110_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC')
    UNION ALL
    SELECT 'ARIMA(1,1,1)', (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_111_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC')
    UNION ALL
    SELECT 'ARIMA(2,1,1)', (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_211_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC')
    UNION ALL
    SELECT 'ARIMA(1,1,2)', (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_112_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC')
    UNION ALL
    SELECT 'ARIMA(2,1,2)', (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_212_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC')
    UNION ALL
    SELECT 'ARIMA(1,0,1)', (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_101_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC')
    UNION ALL
    SELECT 'ARIMA(2,2,2)', (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arima_222_estimate WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC')
)
SELECT TOP 1
    'RECOMMENDED MODEL' as selection_result,
    model as best_model,
    AIC as lowest_AIC,
    'Use this model for TD_ARIMAFORECAST' as next_step
FROM all_models
ORDER BY AIC;

-- ============================================================================
-- CLEANUP (Optional)
-- ============================================================================
/*
-- Uncomment to remove intermediate model tables after selection
DROP TABLE {USER_DATABASE}.arima_011_estimate;
DROP TABLE {USER_DATABASE}.arima_110_estimate;
DROP TABLE {USER_DATABASE}.arima_111_estimate;
DROP TABLE {USER_DATABASE}.arima_211_estimate;
DROP TABLE {USER_DATABASE}.arima_112_estimate;
DROP TABLE {USER_DATABASE}.arima_212_estimate;
DROP TABLE {USER_DATABASE}.arima_101_estimate;
DROP TABLE {USER_DATABASE}.arima_222_estimate;
DROP TABLE {USER_DATABASE}.sarima_111_111_12_estimate;
DROP TABLE {USER_DATABASE}.sarima_011_011_12_estimate;
DROP TABLE {USER_DATABASE}.sarima_111_111_7_estimate;
*/

-- ============================================================================
-- PARAMETER OPTIMIZATION CHECKLIST:
-- ============================================================================
/*
□ Multiple ARIMA specifications tested
□ AIC/BIC values compared across models
□ Seasonal models tested (if applicable)
□ Best model identified based on information criteria
□ Coefficient significance verified for selected model
□ Residual diagnostics checked for best model
□ Ready to proceed with selected model configuration
*/
-- =====================================================
