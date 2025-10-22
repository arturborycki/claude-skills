-- =====================================================
-- TD_ARIMA - Time Series Preprocessing
-- =====================================================
-- Purpose: Prepare time series data for ARIMA modeling
-- Functions: TD_ARIMA, TD_ARIMAPredict
-- =====================================================

-- Check time series data structure
SELECT TOP 20
    {timestamp_column},
    {value_column}
FROM {database}.{timeseries_table}
ORDER BY {timestamp_column};

-- Check for gaps in time series
WITH time_diffs AS (
    SELECT
        {timestamp_column},
        {value_column},
        LAG({timestamp_column}) OVER (ORDER BY {timestamp_column}) as prev_timestamp,
        {timestamp_column} - LAG({timestamp_column}) OVER (ORDER BY {timestamp_column}) as time_diff
    FROM {database}.{timeseries_table}
)
SELECT
    COUNT(*) as total_periods,
    COUNT(DISTINCT time_diff) as distinct_intervals,
    MIN(time_diff) as min_interval,
    MAX(time_diff) as max_interval,
    CASE
        WHEN COUNT(DISTINCT time_diff) = 1 THEN 'Regular intervals'
        ELSE 'Irregular intervals - may need resampling'
    END as regularity_status
FROM time_diffs
WHERE time_diff IS NOT NULL;

-- Create clean time series table
DROP TABLE IF EXISTS {database}.arima_input;
CREATE MULTISET TABLE {database}.arima_input AS (
    SELECT
        {timestamp_column} as time_stamp,
        CAST({value_column} AS FLOAT) as value_col
    FROM {database}.{timeseries_table}
    WHERE {value_column} IS NOT NULL
      AND {timestamp_column} IS NOT NULL
) WITH DATA
PRIMARY INDEX (time_stamp);

-- Time series statistics
SELECT
    COUNT(*) as n_observations,
    MIN(time_stamp) as start_time,
    MAX(time_stamp) as end_time,
    MIN(value_col) as min_value,
    MAX(value_col) as max_value,
    AVG(value_col) as mean_value,
    STDDEV(value_col) as std_dev
FROM {database}.arima_input;

-- Check for stationarity (Augmented Dickey-Fuller test approximation)
-- Look at rolling mean and std
WITH rolling_stats AS (
    SELECT
        time_stamp,
        value_col,
        AVG(value_col) OVER (ORDER BY time_stamp ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) as rolling_mean,
        STDDEV(value_col) OVER (ORDER BY time_stamp ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) as rolling_std
    FROM {database}.arima_input
)
SELECT
    'Stationarity Check' as check_type,
    STDDEV(rolling_mean) as mean_variability,
    STDDEV(rolling_std) as std_variability,
    CASE
        WHEN STDDEV(rolling_mean) / AVG(rolling_mean) < 0.1 THEN 'Likely stationary'
        ELSE 'Likely non-stationary - may need differencing'
    END as stationarity_assessment
FROM rolling_stats;

-- Check for missing timestamps (gaps)
WITH expected_timestamps AS (
    SELECT DISTINCT time_stamp FROM {database}.arima_input
)
SELECT
    'Gap Detection' as check_type,
    COUNT(*) as expected_periods,
    (SELECT COUNT(*) FROM {database}.arima_input) as actual_periods,
    COUNT(*) - (SELECT COUNT(*) FROM {database}.arima_input) as missing_periods
FROM expected_timestamps;

-- Data ready check
SELECT
    'ARIMA Preprocessing Status' as status_type,
    COUNT(*) as n_observations,
    CASE
        WHEN COUNT(*) >= 50 THEN 'READY FOR TD_ARIMA'
        ELSE 'WARNING - Short time series (<50 points)'
    END as readiness
FROM {database}.arima_input;
-- =====================================================
