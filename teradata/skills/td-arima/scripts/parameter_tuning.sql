-- =====================================================
-- TD_ARIMA - Parameter Tuning (p, d, q Selection)
-- =====================================================

-- Test different ARIMA orders and compare AIC/BIC

-- ARIMA(0,1,1)
DROP TABLE IF EXISTS {database}.arima_011;
CREATE MULTISET TABLE {database}.arima_011 AS (
    SELECT * FROM TD_ARIMA (
        ON {database}.arima_input AS InputTable
        USING
        TimeColumn ('time_stamp')
        ValueColumn ('value_col')
        Orders ('0,1,1')
        FitMetrics ('aic', 'bic')
    ) as dt
) WITH DATA;

-- ARIMA(1,1,0)
DROP TABLE IF EXISTS {database}.arima_110;
CREATE MULTISET TABLE {database}.arima_110 AS (
    SELECT * FROM TD_ARIMA (
        ON {database}.arima_input AS InputTable
        USING
        TimeColumn ('time_stamp')
        ValueColumn ('value_col')
        Orders ('1,1,0')
        FitMetrics ('aic', 'bic')
    ) as dt
) WITH DATA;

-- ARIMA(1,1,1)
DROP TABLE IF EXISTS {database}.arima_111;
CREATE MULTISET TABLE {database}.arima_111 AS (
    SELECT * FROM TD_ARIMA (
        ON {database}.arima_input AS InputTable
        USING
        TimeColumn ('time_stamp')
        ValueColumn ('value_col')
        Orders ('1,1,1')
        FitMetrics ('aic', 'bic')
    ) as dt
) WITH DATA;

-- ARIMA(2,1,2)
DROP TABLE IF EXISTS {database}.arima_212;
CREATE MULTISET TABLE {database}.arima_212 AS (
    SELECT * FROM TD_ARIMA (
        ON {database}.arima_input AS InputTable
        USING
        TimeColumn ('time_stamp')
        ValueColumn ('value_col')
        Orders ('2,1,2')
        FitMetrics ('aic', 'bic')
    ) as dt
) WITH DATA;

-- Compare models by AIC/BIC
SELECT
    'ARIMA(0,1,1)' as model,
    (SELECT CAST(metric_value AS DECIMAL(12,4)) FROM {database}.arima_011 WHERE metric_name = 'AIC') as aic,
    (SELECT CAST(metric_value AS DECIMAL(12,4)) FROM {database}.arima_011 WHERE metric_name = 'BIC') as bic

UNION ALL

SELECT
    'ARIMA(1,1,0)' as model,
    (SELECT CAST(metric_value AS DECIMAL(12,4)) FROM {database}.arima_110 WHERE metric_name = 'AIC') as aic,
    (SELECT CAST(metric_value AS DECIMAL(12,4)) FROM {database}.arima_110 WHERE metric_name = 'BIC') as bic

UNION ALL

SELECT
    'ARIMA(1,1,1)' as model,
    (SELECT CAST(metric_value AS DECIMAL(12,4)) FROM {database}.arima_111 WHERE metric_name = 'AIC') as aic,
    (SELECT CAST(metric_value AS DECIMAL(12,4)) FROM {database}.arima_111 WHERE metric_name = 'BIC') as bic

UNION ALL

SELECT
    'ARIMA(2,1,2)' as model,
    (SELECT CAST(metric_value AS DECIMAL(12,4)) FROM {database}.arima_212 WHERE metric_name = 'AIC') as aic,
    (SELECT CAST(metric_value AS DECIMAL(12,4)) FROM {database}.arima_212 WHERE metric_name = 'BIC') as bic

ORDER BY aic;

-- Model selection recommendation
SELECT
    'Model Selection' as recommendation_type,
    'Choose model with lowest AIC/BIC' as guideline,
    'Lower values indicate better fit' as interpretation,
    'Balance complexity vs fit (BIC penalizes complexity more)' as note;
-- =====================================================
