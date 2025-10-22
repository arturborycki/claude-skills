-- =====================================================
-- TD_ARIMAESTIMATE - Result Interpretation
-- =====================================================
-- Purpose: Interpret and visualize ARIMA estimation results
-- Function: TD_ARIMAESTIMATE diagnostic analysis
-- Framework: Teradata Unbounded Array Framework (UAF)
-- =====================================================

-- PREREQUISITE: Run td_arimaestimate_workflow.sql first

-- INSTRUCTIONS:
-- Replace {USER_DATABASE} with your database name

-- ============================================================================
-- STEP 1: Model Coefficients Analysis and Interpretation
-- ============================================================================

-- Detailed coefficient interpretation
SELECT
    coefficient_name,
    CAST(coefficient_value AS DECIMAL(10,6)) as estimated_value,
    CAST(std_error AS DECIMAL(10,6)) as standard_error,
    CAST(coefficient_value / NULLIF(std_error, 0) AS DECIMAL(8,4)) as t_statistic,
    CAST(2 * (1 - NORMAL_CDF(ABS(coefficient_value / NULLIF(std_error, 0)))) AS DECIMAL(8,6)) as p_value_approx,
    CASE
        WHEN ABS(coefficient_value / NULLIF(std_error, 0)) > 2.576 THEN 'Highly significant (99% confidence) ***'
        WHEN ABS(coefficient_value / NULLIF(std_error, 0)) > 1.96 THEN 'Significant (95% confidence) **'
        WHEN ABS(coefficient_value / NULLIF(std_error, 0)) > 1.645 THEN 'Marginally significant (90% confidence) *'
        ELSE 'Not significant'
    END as significance_level,
    CASE coefficient_name
        WHEN 'AR(1)' THEN 'Autoregressive lag 1: Impact of previous value'
        WHEN 'AR(2)' THEN 'Autoregressive lag 2: Impact of value 2 periods ago'
        WHEN 'MA(1)' THEN 'Moving Average lag 1: Impact of previous error term'
        WHEN 'MA(2)' THEN 'Moving Average lag 2: Impact of error term 2 periods ago'
        WHEN 'Intercept' THEN 'Constant term in the model'
        WHEN 'Drift' THEN 'Linear trend component'
        ELSE 'Other model parameter'
    END as interpretation
FROM {USER_DATABASE}.arimaestimate_results
WHERE result_type = 'Coefficients'
ORDER BY coefficient_name;

-- ============================================================================
-- STEP 2: Model Fit Statistics Interpretation
-- ============================================================================

-- Comprehensive fit statistics analysis
SELECT
    statistic_name,
    CAST(statistic_value AS DECIMAL(12,4)) as value,
    CASE statistic_name
        WHEN 'AIC' THEN 'Akaike Information Criterion - compare across models (lower is better)'
        WHEN 'BIC' THEN 'Bayesian Information Criterion - penalizes complexity more than AIC (lower is better)'
        WHEN 'LogLikelihood' THEN 'Log-Likelihood value - higher values indicate better fit'
        WHEN 'Sigma2' THEN 'Residual variance estimate - lower indicates better fit'
        WHEN 'RMSE' THEN 'Root Mean Squared Error - average prediction error magnitude'
        WHEN 'MAE' THEN 'Mean Absolute Error - average absolute prediction error'
        ELSE 'Other fit statistic'
    END as interpretation,
    CASE statistic_name
        WHEN 'AIC' THEN 'Use for model comparison; difference >10 indicates significantly better fit'
        WHEN 'BIC' THEN 'Prefer for model selection when avoiding overfitting is critical'
        WHEN 'LogLikelihood' THEN 'Measures likelihood of data given model parameters'
        WHEN 'Sigma2' THEN 'Residual variance - indicates unexplained variation'
        ELSE 'See Teradata documentation for details'
    END as usage_guidance
FROM {USER_DATABASE}.arimaestimate_results
WHERE result_type = 'FitStatistics'
ORDER BY statistic_name;

-- ============================================================================
-- STEP 3: Residual Diagnostic Analysis
-- ============================================================================

-- Residual summary statistics
WITH residual_stats AS (
    SELECT
        residual,
        CAST(residual / STDDEV(residual) OVER() AS DECIMAL(8,4)) as standardized_residual,
        CASE
            WHEN ABS(residual / STDDEV(residual) OVER()) > 3 THEN 'Extreme outlier'
            WHEN ABS(residual / STDDEV(residual) OVER()) > 2 THEN 'Moderate outlier'
            ELSE 'Normal'
        END as outlier_status
    FROM {USER_DATABASE}.arimaestimate_results
    WHERE result_type = 'Residuals'
)
SELECT
    'Residual Diagnostics' as analysis_type,
    COUNT(*) as n_residuals,
    CAST(AVG(residual) AS DECIMAL(10,6)) as mean_residual,
    CAST(STDDEV(residual) AS DECIMAL(10,6)) as std_residual,
    CAST(MIN(residual) AS DECIMAL(10,6)) as min_residual,
    CAST(MAX(residual) AS DECIMAL(10,6)) as max_residual,
    SUM(CASE WHEN outlier_status = 'Moderate outlier' THEN 1 ELSE 0 END) as moderate_outliers,
    SUM(CASE WHEN outlier_status = 'Extreme outlier' THEN 1 ELSE 0 END) as extreme_outliers,
    CASE
        WHEN ABS(AVG(residual)) < 0.001 * STDDEV(residual) THEN 'Excellent - residuals well-centered at zero'
        WHEN ABS(AVG(residual)) < 0.01 * STDDEV(residual) THEN 'Good - minimal bias in residuals'
        ELSE 'Warning - residuals may be biased'
    END as residual_quality_assessment
FROM residual_stats;

-- ============================================================================
-- STEP 4: Residual Autocorrelation Analysis (Ljung-Box Test)
-- ============================================================================

-- Detailed ACF analysis of residuals
WITH residual_lags AS (
    SELECT
        sequence_id,
        residual,
        LAG(residual, 1) OVER (ORDER BY sequence_id) as lag1,
        LAG(residual, 2) OVER (ORDER BY sequence_id) as lag2,
        LAG(residual, 3) OVER (ORDER BY sequence_id) as lag3,
        LAG(residual, 4) OVER (ORDER BY sequence_id) as lag4,
        LAG(residual, 5) OVER (ORDER BY sequence_id) as lag5,
        LAG(residual, 6) OVER (ORDER BY sequence_id) as lag6,
        LAG(residual, 12) OVER (ORDER BY sequence_id) as lag12,
        LAG(residual, 24) OVER (ORDER BY sequence_id) as lag24
    FROM {USER_DATABASE}.arimaestimate_results
    WHERE result_type = 'Residuals'
)
SELECT
    'Lag' as metric,
    '1' as lag_number,
    CAST(CORR(residual, lag1) AS DECIMAL(8,4)) as autocorrelation,
    CASE WHEN ABS(CORR(residual, lag1)) < 0.1 THEN 'Excellent' WHEN ABS(CORR(residual, lag1)) < 0.2 THEN 'Good' ELSE 'Warning' END as assessment
FROM residual_lags

UNION ALL

SELECT 'Lag', '2', CAST(CORR(residual, lag2) AS DECIMAL(8,4)),
    CASE WHEN ABS(CORR(residual, lag2)) < 0.1 THEN 'Excellent' WHEN ABS(CORR(residual, lag2)) < 0.2 THEN 'Good' ELSE 'Warning' END
FROM residual_lags

UNION ALL

SELECT 'Lag', '3', CAST(CORR(residual, lag3) AS DECIMAL(8,4)),
    CASE WHEN ABS(CORR(residual, lag3)) < 0.1 THEN 'Excellent' WHEN ABS(CORR(residual, lag3)) < 0.2 THEN 'Good' ELSE 'Warning' END
FROM residual_lags

UNION ALL

SELECT 'Lag', '4', CAST(CORR(residual, lag4) AS DECIMAL(8,4)),
    CASE WHEN ABS(CORR(residual, lag4)) < 0.1 THEN 'Excellent' WHEN ABS(CORR(residual, lag4)) < 0.2 THEN 'Good' ELSE 'Warning' END
FROM residual_lags

UNION ALL

SELECT 'Lag', '5', CAST(CORR(residual, lag5) AS DECIMAL(8,4)),
    CASE WHEN ABS(CORR(residual, lag5)) < 0.1 THEN 'Excellent' WHEN ABS(CORR(residual, lag5)) < 0.2 THEN 'Good' ELSE 'Warning' END
FROM residual_lags

UNION ALL

SELECT 'Lag', '6', CAST(CORR(residual, lag6) AS DECIMAL(8,4)),
    CASE WHEN ABS(CORR(residual, lag6)) < 0.1 THEN 'Excellent' WHEN ABS(CORR(residual, lag6)) < 0.2 THEN 'Good' ELSE 'Warning' END
FROM residual_lags

UNION ALL

SELECT 'Lag', '12', CAST(CORR(residual, lag12) AS DECIMAL(8,4)),
    CASE WHEN ABS(CORR(residual, lag12)) < 0.1 THEN 'Excellent' WHEN ABS(CORR(residual, lag12)) < 0.2 THEN 'Good' ELSE 'Warning' END
FROM residual_lags

UNION ALL

SELECT 'Lag', '24', CAST(CORR(residual, lag24) AS DECIMAL(8,4)),
    CASE WHEN ABS(CORR(residual, lag24)) < 0.1 THEN 'Excellent' WHEN ABS(CORR(residual, lag24)) < 0.2 THEN 'Good' ELSE 'Warning' END
FROM residual_lags;

-- Overall autocorrelation assessment
WITH residual_lags AS (
    SELECT
        sequence_id,
        residual,
        LAG(residual, 1) OVER (ORDER BY sequence_id) as lag1,
        LAG(residual, 2) OVER (ORDER BY sequence_id) as lag2,
        LAG(residual, 3) OVER (ORDER BY sequence_id) as lag3
    FROM {USER_DATABASE}.arimaestimate_results
    WHERE result_type = 'Residuals'
)
SELECT
    'Overall Residual Autocorrelation' as analysis_type,
    CASE
        WHEN ABS(CORR(residual, lag1)) < 0.1 AND ABS(CORR(residual, lag2)) < 0.1 AND ABS(CORR(residual, lag3)) < 0.1
        THEN 'Excellent - No significant autocorrelation detected'
        WHEN ABS(CORR(residual, lag1)) < 0.2 AND ABS(CORR(residual, lag2)) < 0.2 AND ABS(CORR(residual, lag3)) < 0.2
        THEN 'Good - Minimal autocorrelation present'
        ELSE 'Warning - Significant autocorrelation detected; model may need refinement'
    END as model_adequacy_assessment,
    CASE
        WHEN ABS(CORR(residual, lag1)) >= 0.2 OR ABS(CORR(residual, lag2)) >= 0.2
        THEN 'Consider increasing AR or MA order'
        ELSE 'Model specification appears adequate'
    END as recommendation
FROM residual_lags;

-- ============================================================================
-- STEP 5: Fitted Values vs Actual - Performance Analysis
-- ============================================================================

-- Detailed performance metrics
WITH performance AS (
    SELECT
        i.time_index,
        i.series_value as actual,
        f.fitted_value as fitted,
        i.series_value - f.fitted_value as error,
        ABS(i.series_value - f.fitted_value) as abs_error,
        POWER(i.series_value - f.fitted_value, 2) as squared_error,
        ABS(i.series_value - f.fitted_value) / NULLIF(ABS(i.series_value), 0) * 100 as pct_error
    FROM {USER_DATABASE}.uaf_arimaestimate_input i
    JOIN (
        SELECT time_index, fitted_value
        FROM {USER_DATABASE}.arimaestimate_results
        WHERE result_type = 'FittedValues'
    ) f ON i.time_index = f.time_index
)
SELECT
    'Model Performance Summary' as metric_category,
    COUNT(*) as n_observations,
    CAST(AVG(abs_error) AS DECIMAL(12,4)) as MAE,
    CAST(SQRT(AVG(squared_error)) AS DECIMAL(12,4)) as RMSE,
    CAST(AVG(pct_error) AS DECIMAL(8,2)) as MAPE_percent,
    CAST(MIN(abs_error) AS DECIMAL(12,4)) as min_error,
    CAST(MAX(abs_error) AS DECIMAL(12,4)) as max_error,
    CAST(1 - (SUM(squared_error) / NULLIF(SUM(POWER(actual - AVG(actual) OVER(), 2)), 0)) AS DECIMAL(8,4)) as R_squared,
    CASE
        WHEN AVG(pct_error) < 5 THEN 'Excellent fit (<5% MAPE)'
        WHEN AVG(pct_error) < 10 THEN 'Very good fit (<10% MAPE)'
        WHEN AVG(pct_error) < 15 THEN 'Good fit (<15% MAPE)'
        WHEN AVG(pct_error) < 20 THEN 'Acceptable fit (<20% MAPE)'
        ELSE 'Poor fit - consider alternative specifications'
    END as fit_quality_assessment
FROM performance;

-- ============================================================================
-- STEP 6: Model Adequacy and Diagnostic Summary
-- ============================================================================

-- Comprehensive diagnostic summary
SELECT
    'ARIMA Model Diagnostic Summary' as summary_section,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients') as n_parameters_estimated,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients' AND ABS(coefficient_value/NULLIF(std_error,0)) > 1.96) as n_significant_parameters,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC,
    (SELECT CAST(statistic_value AS DECIMAL(12,4)) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC') as BIC,
    (
        SELECT CASE
            WHEN ABS(CORR(residual, LAG(residual,1) OVER (ORDER BY sequence_id))) < 0.2 THEN 'Pass'
            ELSE 'Fail'
        END
        FROM {USER_DATABASE}.arimaestimate_results
        WHERE result_type = 'Residuals'
        QUALIFY ROW_NUMBER() OVER (ORDER BY sequence_id) = 1
    ) as residual_autocorrelation_test;

-- ============================================================================
-- STEP 7: Business Interpretation and Recommendations
-- ============================================================================

-- Business-focused interpretation
SELECT
    'Business Interpretation' as section,
    'Model Quality' as aspect,
    CASE
        WHEN (SELECT AVG(ABS(i.series_value - f.fitted_value) / NULLIF(ABS(i.series_value), 0) * 100)
              FROM {USER_DATABASE}.uaf_arimaestimate_input i
              JOIN (SELECT time_index, fitted_value FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'FittedValues') f
              ON i.time_index = f.time_index) < 10
        THEN 'High quality model - suitable for forecasting and decision making'
        WHEN (SELECT AVG(ABS(i.series_value - f.fitted_value) / NULLIF(ABS(i.series_value), 0) * 100)
              FROM {USER_DATABASE}.uaf_arimaestimate_input i
              JOIN (SELECT time_index, fitted_value FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'FittedValues') f
              ON i.time_index = f.time_index) < 20
        THEN 'Acceptable model - use with caution for strategic decisions'
        ELSE 'Model needs improvement - consider additional data or alternative approaches'
    END as interpretation

UNION ALL

SELECT
    'Business Interpretation',
    'Recommended Next Steps',
    CASE
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients' AND ABS(coefficient_value/NULLIF(std_error,0)) > 1.96) >=
             (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients') * 0.7
        THEN 'Model is statistically sound - proceed to forecasting with TD_ARIMAFORECAST'
        ELSE 'Review model specification - many parameters are not significant'
    END

UNION ALL

SELECT
    'Business Interpretation',
    'Forecast Reliability',
    CASE
        WHEN (SELECT STDDEV(residual) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Residuals') /
             (SELECT AVG(ABS(series_value)) FROM {USER_DATABASE}.uaf_arimaestimate_input) < 0.15
        THEN 'Low residual variance - forecasts should be reliable'
        ELSE 'Moderate to high residual variance - forecasts will have wider confidence intervals'
    END;

-- ============================================================================
-- STEP 8: Export Results for Visualization (Optional)
-- ============================================================================

-- Export fitted vs actual for external visualization tools
SELECT
    i.time_index,
    i.series_value as actual_value,
    f.fitted_value as fitted_value,
    i.series_value - f.fitted_value as residual,
    ABS(i.series_value - f.fitted_value) / NULLIF(ABS(i.series_value), 0) * 100 as pct_error
FROM {USER_DATABASE}.uaf_arimaestimate_input i
JOIN (
    SELECT time_index, fitted_value
    FROM {USER_DATABASE}.arimaestimate_results
    WHERE result_type = 'FittedValues'
) f ON i.time_index = f.time_index
ORDER BY i.time_index;

-- ============================================================================
-- RESULT INTERPRETATION CHECKLIST:
-- ============================================================================
/*
□ Coefficient significance reviewed
□ Fit statistics (AIC/BIC) interpreted
□ Residual diagnostics completed
□ Autocorrelation of residuals checked
□ Model performance metrics calculated
□ Business interpretation provided
□ Model adequacy confirmed
□ Ready for forecasting or further refinement
*/
-- =====================================================
