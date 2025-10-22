-- =====================================================
-- TD_ARIMAESTIMATE - Complete UAF Workflow
-- =====================================================
-- Purpose: ARIMA parameter estimation using Teradata UAF
-- Function: TD_ARIMAESTIMATE
-- Framework: Teradata Unbounded Array Framework (UAF)
-- =====================================================

-- PREREQUISITE: Run uaf_data_preparation.sql first

-- INSTRUCTIONS:
-- 1. Replace {USER_DATABASE} with your database name
-- 2. Configure ARIMA orders (p, d, q) based on data analysis
-- 3. Configure seasonal parameters if seasonal patterns detected
-- 4. Adjust estimation parameters based on your requirements

-- ============================================================================
-- STEP 1: Execute TD_ARIMAESTIMATE for Parameter Estimation
-- ============================================================================

-- Basic ARIMA parameter estimation (non-seasonal)
DROP TABLE IF EXISTS {USER_DATABASE}.arimaestimate_results;
CREATE MULTISET TABLE {USER_DATABASE}.arimaestimate_results AS (
    SELECT * FROM TD_ARIMAESTIMATE (
        ON {USER_DATABASE}.uaf_arimaestimate_input
        USING
        TimeColumn('time_index')
        ValueColumn('series_value')
        -- ARIMA Orders: (p, d, q)
        -- p = AR order (0-5 typical)
        -- d = differencing order (0-2 typical)
        -- q = MA order (0-5 typical)
        Orders('1,1,1')  -- Configure based on ACF/PACF analysis

        -- Optional: Seasonal ARIMA parameters
        -- SeasonalOrders('P,D,Q,s')
        -- Example: SeasonalOrders('1,1,1,12') for monthly seasonality

        -- Fitting method
        FitMethod('ML')  -- Maximum Likelihood (alternatives: CSS, CSS-ML)

        -- Include fit statistics
        IncludeFitStats('true')

        -- Missing value handling
        -- MissingValueMethod('linear') -- Optional: linear, previous, next, omit
    ) AS dt
) WITH DATA;

-- ============================================================================
-- STEP 2: Extract and Review Model Coefficients
-- ============================================================================

-- View estimated ARIMA coefficients
SELECT
    model_id,
    coefficient_name,
    CAST(coefficient_value AS DECIMAL(10,6)) as estimated_value,
    CAST(std_error AS DECIMAL(10,6)) as standard_error,
    CAST(coefficient_value / NULLIF(std_error, 0) AS DECIMAL(8,4)) as t_statistic,
    CASE
        WHEN ABS(coefficient_value / NULLIF(std_error, 0)) > 1.96 THEN 'Significant (95% confidence)'
        WHEN ABS(coefficient_value / NULLIF(std_error, 0)) > 1.645 THEN 'Marginally significant (90% confidence)'
        ELSE 'Not significant'
    END as significance_assessment
FROM {USER_DATABASE}.arimaestimate_results
WHERE result_type = 'Coefficients'
ORDER BY coefficient_name;

-- ============================================================================
-- STEP 3: Review Model Fit Statistics
-- ============================================================================

-- Extract AIC, BIC, and other fit statistics
SELECT
    model_id,
    statistic_name,
    CAST(statistic_value AS DECIMAL(12,4)) as value,
    CASE statistic_name
        WHEN 'AIC' THEN 'Akaike Information Criterion - lower is better'
        WHEN 'BIC' THEN 'Bayesian Information Criterion - lower is better'
        WHEN 'LogLikelihood' THEN 'Log-Likelihood - higher is better'
        WHEN 'Sigma2' THEN 'Residual variance estimate'
        ELSE 'Other fit statistic'
    END as interpretation
FROM {USER_DATABASE}.arimaestimate_results
WHERE result_type = 'FitStatistics'
ORDER BY statistic_name;

-- ============================================================================
-- STEP 4: Analyze Model Residuals
-- ============================================================================

-- Residual analysis for model diagnostics
WITH residuals AS (
    SELECT
        time_index,
        CAST(residual AS DECIMAL(12,6)) as residual_value,
        CAST(residual / STDDEV(residual) OVER() AS DECIMAL(8,4)) as standardized_residual
    FROM {USER_DATABASE}.arimaestimate_results
    WHERE result_type = 'Residuals'
)
SELECT
    COUNT(*) as n_residuals,
    CAST(AVG(residual_value) AS DECIMAL(10,6)) as mean_residual,
    CAST(STDDEV(residual_value) AS DECIMAL(10,6)) as std_residual,
    CAST(MIN(residual_value) AS DECIMAL(10,6)) as min_residual,
    CAST(MAX(residual_value) AS DECIMAL(10,6)) as max_residual,
    SUM(CASE WHEN ABS(standardized_residual) > 2 THEN 1 ELSE 0 END) as outlier_count_2sd,
    SUM(CASE WHEN ABS(standardized_residual) > 3 THEN 1 ELSE 0 END) as outlier_count_3sd,
    CASE
        WHEN ABS(AVG(residual_value)) < 0.001 * STDDEV(residual_value) THEN 'Good - residuals centered at zero'
        ELSE 'Warning - residuals may be biased'
    END as residual_quality
FROM residuals;

-- ============================================================================
-- STEP 5: Residual Autocorrelation Check (Ljung-Box Test Approximation)
-- ============================================================================

-- Check for residual autocorrelation
WITH residuals AS (
    SELECT
        time_index,
        residual,
        sequence_id,
        LAG(residual, 1) OVER (ORDER BY sequence_id) as lag1,
        LAG(residual, 2) OVER (ORDER BY sequence_id) as lag2,
        LAG(residual, 3) OVER (ORDER BY sequence_id) as lag3,
        LAG(residual, 4) OVER (ORDER BY sequence_id) as lag4,
        LAG(residual, 5) OVER (ORDER BY sequence_id) as lag5,
        LAG(residual, 6) OVER (ORDER BY sequence_id) as lag6
    FROM {USER_DATABASE}.arimaestimate_results
    WHERE result_type = 'Residuals'
)
SELECT
    'Residual Autocorrelation Analysis' as analysis_type,
    CAST(CORR(residual, lag1) AS DECIMAL(8,4)) as acf_lag1,
    CAST(CORR(residual, lag2) AS DECIMAL(8,4)) as acf_lag2,
    CAST(CORR(residual, lag3) AS DECIMAL(8,4)) as acf_lag3,
    CAST(CORR(residual, lag4) AS DECIMAL(8,4)) as acf_lag4,
    CAST(CORR(residual, lag5) AS DECIMAL(8,4)) as acf_lag5,
    CAST(CORR(residual, lag6) AS DECIMAL(8,4)) as acf_lag6,
    CASE
        WHEN ABS(CORR(residual, lag1)) < 0.15
         AND ABS(CORR(residual, lag2)) < 0.15
         AND ABS(CORR(residual, lag3)) < 0.15
        THEN 'Excellent - No significant autocorrelation in residuals'
        WHEN ABS(CORR(residual, lag1)) < 0.25
         AND ABS(CORR(residual, lag2)) < 0.25
        THEN 'Good - Minimal autocorrelation'
        ELSE 'Warning - Residual autocorrelation detected, model may need refinement'
    END as assessment
FROM residuals;

-- ============================================================================
-- STEP 6: Compare Fitted Values vs Actual Values
-- ============================================================================

-- Fitted values comparison
SELECT
    i.time_index,
    i.series_value as actual_value,
    f.fitted_value as fitted_value,
    i.series_value - f.fitted_value as residual,
    ABS(i.series_value - f.fitted_value) as absolute_error,
    ABS(i.series_value - f.fitted_value) / NULLIF(ABS(i.series_value), 0) * 100 as percent_error
FROM {USER_DATABASE}.uaf_arimaestimate_input i
JOIN (
    SELECT time_index, fitted_value
    FROM {USER_DATABASE}.arimaestimate_results
    WHERE result_type = 'FittedValues'
) f ON i.time_index = f.time_index
ORDER BY i.time_index;

-- ============================================================================
-- STEP 7: Model Performance Metrics
-- ============================================================================

-- Calculate overall model accuracy metrics
WITH errors AS (
    SELECT
        i.series_value as actual,
        f.fitted_value as fitted,
        i.series_value - f.fitted_value as error,
        ABS(i.series_value - f.fitted_value) as abs_error,
        POWER(i.series_value - f.fitted_value, 2) as squared_error
    FROM {USER_DATABASE}.uaf_arimaestimate_input i
    JOIN (
        SELECT time_index, fitted_value
        FROM {USER_DATABASE}.arimaestimate_results
        WHERE result_type = 'FittedValues'
    ) f ON i.time_index = f.time_index
)
SELECT
    'Model Performance Metrics' as metric_category,
    CAST(AVG(abs_error) AS DECIMAL(12,4)) as MAE,
    CAST(SQRT(AVG(squared_error)) AS DECIMAL(12,4)) as RMSE,
    CAST(AVG(abs_error) / NULLIF(AVG(ABS(actual)), 0) * 100 AS DECIMAL(8,2)) as MAPE_percent,
    CAST(1 - (SUM(squared_error) / NULLIF(SUM(POWER(actual - AVG(actual) OVER(), 2)), 0)) AS DECIMAL(8,4)) as R_squared,
    CASE
        WHEN AVG(abs_error) / NULLIF(AVG(ABS(actual)), 0) < 0.10 THEN 'Excellent fit (<10% error)'
        WHEN AVG(abs_error) / NULLIF(AVG(ABS(actual)), 0) < 0.20 THEN 'Good fit (<20% error)'
        WHEN AVG(abs_error) / NULLIF(AVG(ABS(actual)), 0) < 0.30 THEN 'Acceptable fit (<30% error)'
        ELSE 'Poor fit - consider alternative parameters'
    END as model_quality_assessment
FROM errors;

-- ============================================================================
-- STEP 8: Model Summary and Recommendations
-- ============================================================================

-- Comprehensive model summary
SELECT
    'TD_ARIMAESTIMATE Summary' as summary_section,
    (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_arimaestimate_input) as n_observations,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients') as n_parameters,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC') as BIC,
    CURRENT_TIMESTAMP as analysis_timestamp;

-- Next Steps Recommendations
SELECT
    'Next Steps' as recommendation_type,
    CASE
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients') > 0
        THEN 'Parameter estimation successful - proceed to forecasting with TD_ARIMAFORECAST'
        ELSE 'Check model specification and data quality'
    END as recommendation;

-- ============================================================================
-- CLEANUP (Optional - comment out to preserve results)
-- ============================================================================
-- DROP TABLE {USER_DATABASE}.arimaestimate_results;

-- ============================================================================
-- UAF TD_ARIMAESTIMATE WORKFLOW CHECKLIST:
-- ============================================================================
/*
□ Data preparation completed (uaf_data_preparation.sql)
□ ARIMA orders configured based on ACF/PACF analysis
□ Seasonal parameters configured (if applicable)
□ Model estimation executed successfully
□ Coefficients reviewed for significance
□ Fit statistics (AIC/BIC) evaluated
□ Residuals analyzed for autocorrelation
□ Model performance metrics calculated
□ Results ready for forecasting workflow
□ Proceed to td_arimaforecast_workflow.sql for predictions
*/
-- =====================================================
