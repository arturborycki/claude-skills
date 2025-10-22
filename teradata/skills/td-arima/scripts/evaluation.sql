-- =====================================================
-- TD_ARIMA - Model Evaluation
-- =====================================================
-- Purpose: Evaluate ARIMA model forecast accuracy
-- =====================================================

-- Holdout validation (if data split was done)
-- Compare forecasts to actual values
WITH forecast_eval AS (
    SELECT
        a.time_stamp,
        a.value_col as actual,
        f.forecast_value as forecast,
        (f.forecast_value - a.value_col) as error,
        POWER(f.forecast_value - a.value_col, 2) as squared_error,
        ABS(f.forecast_value - a.value_col) as absolute_error,
        ABS((f.forecast_value - a.value_col) / NULLIF(a.value_col, 0)) * 100 as percentage_error
    FROM {database}.arima_input a
    INNER JOIN {database}.arima_forecasts f ON a.time_stamp = f.time_stamp
    WHERE f.forecast_value IS NOT NULL
)
SELECT
    'Forecast Accuracy Metrics' as metric_type,
    COUNT(*) as n_forecasts,
    CAST(SQRT(AVG(squared_error)) AS DECIMAL(12,6)) as rmse,
    CAST(AVG(absolute_error) AS DECIMAL(12,6)) as mae,
    CAST(AVG(percentage_error) AS DECIMAL(8,2)) as mape,
    CAST(AVG(error) AS DECIMAL(12,6)) as mean_bias
FROM forecast_eval;

-- Residual diagnostics
SELECT
    'Residual Diagnostics' as diagnostic_type,
    COUNT(*) as n_residuals,
    CAST(AVG(residual) AS DECIMAL(12,6)) as mean_residual,
    CAST(STDDEV(residual) AS DECIMAL(12,6)) as std_residual,
    CAST(MIN(residual) AS DECIMAL(12,6)) as min_residual,
    CAST(MAX(residual) AS DECIMAL(12,6)) as max_residual
FROM {database}.arima_model
WHERE result_type = 'Residuals';

-- Check if residuals are white noise (no autocorrelation)
-- Ljung-Box Q-statistic approximation
WITH residuals AS (
    SELECT
        residual,
        LAG(residual, 1) OVER (ORDER BY time_stamp) as lag1,
        LAG(residual, 2) OVER (ORDER BY time_stamp) as lag2
    FROM {database}.arima_model
    WHERE result_type = 'Residuals'
)
SELECT
    'Autocorrelation Check' as check_type,
    CAST(CORR(residual, lag1) AS DECIMAL(8,4)) as lag1_autocorr,
    CAST(CORR(residual, lag2) AS DECIMAL(8,4)) as lag2_autocorr,
    CASE
        WHEN ABS(CORR(residual, lag1)) < 0.2 AND ABS(CORR(residual, lag2)) < 0.2
        THEN 'Good - Residuals appear white noise'
        ELSE 'Warning - Residuals show autocorrelation'
    END as assessment
FROM residuals;

-- Model fit statistics
SELECT
    result_type,
    metric_name,
    CAST(metric_value AS DECIMAL(12,4)) as value
FROM {database}.arima_model
WHERE result_type = 'FitStatistics'
ORDER BY metric_name;
-- =====================================================
