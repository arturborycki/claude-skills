-- =====================================================
-- TD_ARIMA - Diagnostic Queries
-- =====================================================

-- View model coefficients
SELECT
    coefficient_name,
    CAST(coefficient_value AS DECIMAL(10,6)) as value,
    CAST(std_error AS DECIMAL(10,6)) as std_error,
    CAST(coefficient_value / NULLIF(std_error, 0) AS DECIMAL(8,4)) as t_statistic
FROM {database}.arima_model
WHERE result_type = 'Coefficients'
ORDER BY coefficient_name;

-- Residual analysis
SELECT
    time_stamp,
    CAST(residual AS DECIMAL(12,6)) as residual,
    CAST(residual / STDDEV(residual) OVER() AS DECIMAL(8,4)) as standardized_residual
FROM {database}.arima_model
WHERE result_type = 'Residuals'
ORDER BY time_stamp;

-- Residual ACF/PACF (autocorrelation check)
WITH residuals AS (
    SELECT
        time_stamp,
        residual,
        LAG(residual, 1) OVER (ORDER BY time_stamp) as lag1,
        LAG(residual, 2) OVER (ORDER BY time_stamp) as lag2,
        LAG(residual, 3) OVER (ORDER BY time_stamp) as lag3
    FROM {database}.arima_model
    WHERE result_type = 'Residuals'
)
SELECT
    'Residual Autocorrelation' as analysis_type,
    CAST(CORR(residual, lag1) AS DECIMAL(8,4)) as acf_lag1,
    CAST(CORR(residual, lag2) AS DECIMAL(8,4)) as acf_lag2,
    CAST(CORR(residual, lag3) AS DECIMAL(8,4)) as acf_lag3,
    CASE
        WHEN ABS(CORR(residual, lag1)) < 0.2 AND ABS(CORR(residual, lag2)) < 0.2 AND ABS(CORR(residual, lag3)) < 0.2
        THEN 'Good - No significant autocorrelation'
        ELSE 'Warning - Autocorrelation detected'
    END as assessment
FROM residuals;

-- Fitted values vs actuals
SELECT
    i.time_stamp,
    i.value_col as actual,
    m.fitted_value as fitted,
    i.value_col - m.fitted_value as residual
FROM {database}.arima_input i
LEFT JOIN (SELECT time_stamp, fitted_value FROM {database}.arima_model WHERE result_type = 'FittedValues') m
    ON i.time_stamp = m.time_stamp
ORDER BY i.time_stamp;

-- Model information
SELECT
    info_name,
    info_value
FROM {database}.arima_model
WHERE result_type = 'ModelInfo'
ORDER BY info_name;

-- Forecast confidence intervals
SELECT
    time_stamp,
    CAST(forecast_value AS DECIMAL(12,4)) as forecast,
    CAST(lower_bound AS DECIMAL(12,4)) as lower_95,
    CAST(upper_bound AS DECIMAL(12,4)) as upper_95,
    CAST(upper_bound - lower_bound AS DECIMAL(12,4)) as ci_width
FROM {database}.arima_forecasts
WHERE forecast_value IS NOT NULL
ORDER BY time_stamp;
-- =====================================================
