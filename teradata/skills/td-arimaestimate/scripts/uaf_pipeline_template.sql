-- =====================================================
-- TD_ARIMAESTIMATE - UAF Pipeline Template
-- =====================================================
-- Purpose: Complete UAF pipeline integrating multiple functions
-- Functions: TD_ARIMAESTIMATE + complementary UAF functions
-- Framework: Teradata Unbounded Array Framework (UAF)
-- =====================================================

-- This template demonstrates end-to-end UAF time series analysis
-- combining TD_ARIMAESTIMATE with other UAF functions

-- INSTRUCTIONS:
-- Replace {USER_DATABASE}, {USER_TABLE}, {TIMESTAMP_COLUMN}, {VALUE_COLUMNS}

-- ============================================================================
-- PIPELINE STAGE 1: Data Preparation and Stationarity Testing
-- ============================================================================

-- Create base UAF input table
DROP TABLE IF EXISTS {USER_DATABASE}.uaf_base_data;
CREATE MULTISET TABLE {USER_DATABASE}.uaf_base_data AS (
    SELECT
        {TIMESTAMP_COLUMN} as time_index,
        CAST({VALUE_COLUMNS} AS FLOAT) as series_value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as sequence_id
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {VALUE_COLUMNS} IS NOT NULL
      AND {TIMESTAMP_COLUMN} IS NOT NULL
    ORDER BY {TIMESTAMP_COLUMN}
) WITH DATA;

-- Test for stationarity using TD_StationarityTest (if available)
DROP TABLE IF EXISTS {USER_DATABASE}.stationarity_test_results;
CREATE MULTISET TABLE {USER_DATABASE}.stationarity_test_results AS (
    SELECT * FROM TD_StationarityTest (
        ON {USER_DATABASE}.uaf_base_data
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        TestType('ADF')  -- Augmented Dickey-Fuller test
        MaxLag(12)
    ) AS dt
) WITH DATA;

-- Review stationarity test results
SELECT
    test_name,
    test_statistic,
    p_value,
    CASE
        WHEN p_value < 0.05 THEN 'Series is stationary (reject null hypothesis)'
        ELSE 'Series is non-stationary (fail to reject null hypothesis) - differencing recommended'
    END as interpretation
FROM {USER_DATABASE}.stationarity_test_results;

-- ============================================================================
-- PIPELINE STAGE 2: ACF and PACF Analysis for Parameter Selection
-- ============================================================================

-- Compute ACF (Autocorrelation Function)
DROP TABLE IF EXISTS {USER_DATABASE}.acf_results;
CREATE MULTISET TABLE {USER_DATABASE}.acf_results AS (
    SELECT * FROM TD_ACF (
        ON {USER_DATABASE}.uaf_base_data
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        MaxLag(24)
        ConfidenceLevel(0.95)
    ) AS dt
) WITH DATA;

-- Compute PACF (Partial Autocorrelation Function)
DROP TABLE IF EXISTS {USER_DATABASE}.pacf_results;
CREATE MULTISET TABLE {USER_DATABASE}.pacf_results AS (
    SELECT * FROM TD_PACF (
        ON {USER_DATABASE}.uaf_base_data
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        MaxLag(24)
        ConfidenceLevel(0.95)
    ) AS dt
) WITH DATA;

-- Review ACF results to determine MA(q) order
SELECT
    lag,
    CAST(acf_value AS DECIMAL(8,4)) as autocorrelation,
    CAST(lower_bound AS DECIMAL(8,4)) as lower_95,
    CAST(upper_bound AS DECIMAL(8,4)) as upper_95,
    CASE
        WHEN acf_value > upper_bound OR acf_value < lower_bound THEN 'Significant'
        ELSE 'Not significant'
    END as significance
FROM {USER_DATABASE}.acf_results
WHERE lag > 0
ORDER BY lag;

-- Review PACF results to determine AR(p) order
SELECT
    lag,
    CAST(pacf_value AS DECIMAL(8,4)) as partial_autocorrelation,
    CAST(lower_bound AS DECIMAL(8,4)) as lower_95,
    CAST(upper_bound AS DECIMAL(8,4)) as upper_95,
    CASE
        WHEN pacf_value > upper_bound OR pacf_value < lower_bound THEN 'Significant'
        ELSE 'Not significant'
    END as significance
FROM {USER_DATABASE}.pacf_results
WHERE lag > 0
ORDER BY lag;

-- ============================================================================
-- PIPELINE STAGE 3: Apply Differencing if Needed
-- ============================================================================

-- Apply first-order differencing if series is non-stationary
DROP TABLE IF EXISTS {USER_DATABASE}.differenced_data;
CREATE MULTISET TABLE {USER_DATABASE}.differenced_data AS (
    SELECT * FROM TD_Diff (
        ON {USER_DATABASE}.uaf_base_data
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        DifferenceOrder(1)  -- First-order differencing
        -- SeasonalDifference(1)  -- Add if seasonal pattern exists
        -- Period(12)  -- Seasonal period
    ) AS dt
) WITH DATA;

-- Review differenced series
SELECT
    time_index,
    differenced_value,
    sequence_id
FROM {USER_DATABASE}.differenced_data
ORDER BY sequence_id;

-- ============================================================================
-- PIPELINE STAGE 4: Seasonal Decomposition (if seasonal patterns exist)
-- ============================================================================

-- Decompose time series into trend, seasonal, and residual components
DROP TABLE IF EXISTS {USER_DATABASE}.seasonal_decompose_results;
CREATE MULTISET TABLE {USER_DATABASE}.seasonal_decompose_results AS (
    SELECT * FROM TD_SeasonalDecompose (
        ON {USER_DATABASE}.uaf_base_data
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        Period(12)  -- Adjust based on your seasonal period
        DecompositionType('additive')  -- or 'multiplicative'
    ) AS dt
) WITH DATA;

-- Review seasonal components
SELECT
    time_index,
    CAST(trend AS DECIMAL(12,4)) as trend_component,
    CAST(seasonal AS DECIMAL(12,4)) as seasonal_component,
    CAST(residual AS DECIMAL(12,4)) as residual_component
FROM {USER_DATABASE}.seasonal_decompose_results
ORDER BY time_index;

-- ============================================================================
-- PIPELINE STAGE 5: ARIMA Parameter Estimation
-- ============================================================================

-- Execute TD_ARIMAESTIMATE with parameters determined from ACF/PACF
DROP TABLE IF EXISTS {USER_DATABASE}.arima_estimation;
CREATE MULTISET TABLE {USER_DATABASE}.arima_estimation AS (
    SELECT * FROM TD_ARIMAESTIMATE (
        ON {USER_DATABASE}.uaf_base_data  -- Or use differenced_data if pre-differencing
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        -- Configure orders based on ACF/PACF analysis:
        -- p = number of significant PACF lags
        -- d = differencing order from stationarity test
        -- q = number of significant ACF lags
        Orders('1,1,1')  -- Example: ARIMA(1,1,1)

        -- Add seasonal parameters if seasonal decomposition showed strong patterns:
        -- SeasonalOrders('P,D,Q,s')
        -- Example: SeasonalOrders('1,1,1,12')

        FitMethod('ML')
        IncludeFitStats('true')
    ) AS dt
) WITH DATA;

-- Review estimated parameters
SELECT
    coefficient_name,
    CAST(coefficient_value AS DECIMAL(10,6)) as value,
    CAST(std_error AS DECIMAL(10,6)) as std_error,
    CASE
        WHEN ABS(coefficient_value / NULLIF(std_error, 0)) > 1.96 THEN 'Significant'
        ELSE 'Not significant'
    END as significance
FROM {USER_DATABASE}.arima_estimation
WHERE result_type = 'Coefficients';

-- ============================================================================
-- PIPELINE STAGE 6: Residual Diagnostics with ACF
-- ============================================================================

-- Extract residuals from ARIMA estimation
DROP TABLE IF EXISTS {USER_DATABASE}.arima_residuals;
CREATE MULTISET TABLE {USER_DATABASE}.arima_residuals AS (
    SELECT
        sequence_id,
        time_index,
        residual as series_value
    FROM {USER_DATABASE}.arima_estimation
    WHERE result_type = 'Residuals'
) WITH DATA;

-- Analyze residual ACF (should be white noise - no significant autocorrelation)
DROP TABLE IF EXISTS {USER_DATABASE}.residual_acf;
CREATE MULTISET TABLE {USER_DATABASE}.residual_acf AS (
    SELECT * FROM TD_ACF (
        ON {USER_DATABASE}.arima_residuals
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        MaxLag(20)
        ConfidenceLevel(0.95)
    ) AS dt
) WITH DATA;

-- Check residual autocorrelation
SELECT
    lag,
    CAST(acf_value AS DECIMAL(8,4)) as residual_acf,
    CASE
        WHEN acf_value > upper_bound OR acf_value < lower_bound THEN 'WARNING: Significant autocorrelation'
        ELSE 'OK: No significant autocorrelation'
    END as diagnostic
FROM {USER_DATABASE}.residual_acf
WHERE lag > 0
ORDER BY lag;

-- ============================================================================
-- PIPELINE STAGE 7: Forecasting with TD_ARIMAFORECAST
-- ============================================================================

-- Generate forecasts using estimated parameters
DROP TABLE IF EXISTS {USER_DATABASE}.arima_forecasts;
CREATE MULTISET TABLE {USER_DATABASE}.arima_forecasts AS (
    SELECT * FROM TD_ARIMAFORECAST (
        ON {USER_DATABASE}.uaf_base_data AS InputTable
        ON {USER_DATABASE}.arima_estimation AS ModelTable
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        ForecastPeriods(12)  -- Forecast next 12 periods
        ConfidenceLevel(0.95)
    ) AS dt
) WITH DATA;

-- Review forecasts with confidence intervals
SELECT
    forecast_period,
    forecast_time,
    CAST(forecast_value AS DECIMAL(12,4)) as forecast,
    CAST(lower_bound AS DECIMAL(12,4)) as lower_95_ci,
    CAST(upper_bound AS DECIMAL(12,4)) as upper_95_ci,
    CAST(upper_bound - lower_bound AS DECIMAL(12,4)) as ci_width
FROM {USER_DATABASE}.arima_forecasts
ORDER BY forecast_period;

-- ============================================================================
-- PIPELINE STAGE 8: Visualization Preparation with TD_Plot
-- ============================================================================

-- Prepare data for visualization (actual + fitted + forecast)
DROP TABLE IF EXISTS {USER_DATABASE}.visualization_data;
CREATE MULTISET TABLE {USER_DATABASE}.visualization_data AS (
    SELECT
        time_index,
        'Actual' as series_type,
        series_value as value
    FROM {USER_DATABASE}.uaf_base_data

    UNION ALL

    SELECT
        time_index,
        'Fitted' as series_type,
        fitted_value as value
    FROM {USER_DATABASE}.arima_estimation
    WHERE result_type = 'FittedValues'

    UNION ALL

    SELECT
        forecast_time as time_index,
        'Forecast' as series_type,
        forecast_value as value
    FROM {USER_DATABASE}.arima_forecasts
) WITH DATA;

-- Export for visualization
SELECT * FROM {USER_DATABASE}.visualization_data
ORDER BY time_index, series_type;

-- ============================================================================
-- PIPELINE STAGE 9: Performance Monitoring and Validation
-- ============================================================================

-- Calculate pipeline execution metrics
SELECT
    'UAF Pipeline Summary' as metric_category,
    (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_base_data) as input_observations,
    (SELECT statistic_value FROM {USER_DATABASE}.arima_estimation WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as final_model_aic,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arima_forecasts) as forecast_periods,
    (
        SELECT COUNT(*)
        FROM {USER_DATABASE}.residual_acf
        WHERE lag > 0 AND (acf_value > upper_bound OR acf_value < lower_bound)
    ) as n_significant_residual_lags,
    CASE
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.residual_acf WHERE lag > 0 AND (acf_value > upper_bound OR acf_value < lower_bound)) = 0
        THEN 'Excellent - Model residuals are white noise'
        ELSE 'Warning - Some residual autocorrelation remains'
    END as model_adequacy,
    CURRENT_TIMESTAMP as pipeline_completion_time;

-- ============================================================================
-- PIPELINE SUMMARY AND RECOMMENDATIONS
-- ============================================================================

SELECT
    'UAF Time Series Pipeline Complete' as status,
    'Data prepared, stationarity tested, parameters optimized, forecasts generated' as summary,
    'Review forecast confidence intervals and residual diagnostics' as recommendation,
    'Consider backtesting for validation' as next_steps;

-- ============================================================================
-- CLEANUP (Optional)
-- ============================================================================
/*
-- Uncomment to clean up intermediate tables
DROP TABLE {USER_DATABASE}.uaf_base_data;
DROP TABLE {USER_DATABASE}.stationarity_test_results;
DROP TABLE {USER_DATABASE}.acf_results;
DROP TABLE {USER_DATABASE}.pacf_results;
DROP TABLE {USER_DATABASE}.differenced_data;
DROP TABLE {USER_DATABASE}.seasonal_decompose_results;
DROP TABLE {USER_DATABASE}.arima_residuals;
DROP TABLE {USER_DATABASE}.residual_acf;
*/

-- Keep these tables for analysis:
-- - arima_estimation (model parameters)
-- - arima_forecasts (predictions)
-- - visualization_data (for reporting)

-- ============================================================================
-- UAF PIPELINE CHECKLIST:
-- ============================================================================
/*
□ Stationarity tested and differencing applied if needed
□ ACF/PACF analyzed for parameter selection
□ Seasonal patterns identified and incorporated
□ ARIMA parameters estimated successfully
□ Residuals checked for white noise properties
□ Forecasts generated with confidence intervals
□ Visualization data prepared
□ Pipeline performance metrics calculated
□ Model adequacy confirmed
□ Ready for production deployment or further validation
*/
-- =====================================================
