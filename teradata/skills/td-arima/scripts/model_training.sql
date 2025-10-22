-- =====================================================
-- TD_ARIMA - Model Training
-- =====================================================
-- Purpose: Fit ARIMA model to time series data
-- Function: TD_ARIMA
-- =====================================================

-- Fit ARIMA model
-- ARIMA(p,d,q): p=AR order, d=differencing, q=MA order
DROP TABLE IF EXISTS {database}.arima_model;
CREATE MULTISET TABLE {database}.arima_model AS (
    SELECT * FROM TD_ARIMA (
        ON {database}.arima_input AS InputTable
        USING
        TimeColumn ('time_stamp')
        ValueColumn ('value_col')
        Orders ('1,1,1')  -- ARIMA(1,1,1) - adjust as needed
        -- Alternative orders to try:
        -- Orders ('0,1,1')  -- ARIMA(0,1,1) - Simple MA model
        -- Orders ('1,1,0')  -- ARIMA(1,1,0) - Simple AR model
        -- Orders ('2,1,2')  -- ARIMA(2,1,2) - More complex
        FitMetrics ('aic', 'bic')  -- Information criteria
    ) as dt
) WITH DATA;

-- View model coefficients
SELECT * FROM {database}.arima_model
WHERE result_type = 'Coefficients';

-- View model diagnostics
SELECT * FROM {database}.arima_model
WHERE result_type = 'ModelInfo';

-- Extract AIC/BIC for model comparison
SELECT
    metric_name,
    CAST(metric_value AS DECIMAL(12,4)) as value
FROM {database}.arima_model
WHERE result_type = 'FitStatistics'
ORDER BY metric_name;

-- Model summary
SELECT
    'ARIMA Model Summary' as summary_type,
    (SELECT COUNT(*) FROM {database}.arima_input) as training_observations,
    (SELECT metric_value FROM {database}.arima_model WHERE result_type = 'FitStatistics' AND metric_name = 'AIC') as aic,
    (SELECT metric_value FROM {database}.arima_model WHERE result_type = 'FitStatistics' AND metric_name = 'BIC') as bic,
    CASE
        WHEN (SELECT metric_value FROM {database}.arima_model WHERE result_type = 'FitStatistics' AND metric_name = 'AIC') IS NOT NULL
        THEN 'Model fitted successfully'
        ELSE 'Model fitting failed'
    END as fit_status;

-- Residual analysis
SELECT
    AVG(residual) as mean_residual,
    STDDEV(residual) as std_residual,
    MIN(residual) as min_residual,
    MAX(residual) as max_residual
FROM {database}.arima_model
WHERE result_type = 'Residuals';
-- =====================================================
