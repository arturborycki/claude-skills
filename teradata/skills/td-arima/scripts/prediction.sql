-- =====================================================
-- TD_ARIMA - Forecasting
-- =====================================================
-- Purpose: Generate forecasts using fitted ARIMA model
-- Function: TD_ARIMAPredict
-- =====================================================

-- Generate forecasts
DROP TABLE IF EXISTS {database}.arima_forecasts;
CREATE MULTISET TABLE {database}.arima_forecasts AS (
    SELECT * FROM TD_ARIMAPredict (
        ON {database}.arima_input AS InputTable
        ON {database}.arima_model AS ModelTable
        USING
        TimeColumn ('time_stamp')
        ValueColumn ('value_col')
        Steps (12)  -- Forecast 12 periods ahead
        ConfidenceLevel (0.95)  -- 95% confidence intervals
    ) as dt
) WITH DATA;

-- View forecasts
SELECT
    time_stamp,
    CAST(forecast_value AS DECIMAL(12,4)) as forecast,
    CAST(lower_bound AS DECIMAL(12,4)) as lower_95,
    CAST(upper_bound AS DECIMAL(12,4)) as upper_95
FROM {database}.arima_forecasts
WHERE forecast_value IS NOT NULL
ORDER BY time_stamp;

-- Plot forecast vs actuals (for periods with both)
SELECT
    a.time_stamp,
    a.value_col as actual,
    f.forecast_value as forecast,
    ABS(a.value_col - f.forecast_value) as absolute_error
FROM {database}.arima_input a
LEFT JOIN {database}.arima_forecasts f ON a.time_stamp = f.time_stamp
WHERE f.forecast_value IS NOT NULL
ORDER BY a.time_stamp;

-- Forecast summary
SELECT
    'Forecast Summary' as summary_type,
    COUNT(*) as n_forecasts,
    MIN(forecast_value) as min_forecast,
    MAX(forecast_value) as max_forecast,
    AVG(forecast_value) as mean_forecast,
    AVG(upper_bound - lower_bound) as avg_ci_width
FROM {database}.arima_forecasts
WHERE forecast_value IS NOT NULL;
-- =====================================================
