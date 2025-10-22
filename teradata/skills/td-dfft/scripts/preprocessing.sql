-- =====================================================
-- TD_DFFT - Discrete Fast Fourier Transform Preprocessing
-- =====================================================
-- Purpose: Prepare time series for frequency analysis
-- Function: TD_DFFT
-- =====================================================

-- Check time series data
SELECT TOP 20
    {timestamp_column},
    {value_column}
FROM {database}.{timeseries_table}
ORDER BY {timestamp_column};

-- Create clean time series input
DROP TABLE IF EXISTS {database}.dfft_input;
CREATE MULTISET TABLE {database}.dfft_input AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY {timestamp_column}) as sequence_id,
        {timestamp_column} as time_stamp,
        CAST({value_column} AS FLOAT) as value_col
    FROM {database}.{timeseries_table}
    WHERE {value_column} IS NOT NULL
      AND {timestamp_column} IS NOT NULL
) WITH DATA
PRIMARY INDEX (sequence_id);

-- Time series statistics
SELECT
    COUNT(*) as n_observations,
    MIN(value_col) as min_value,
    MAX(value_col) as max_value,
    AVG(value_col) as mean_value,
    STDDEV(value_col) as std_value
FROM {database}.dfft_input;

-- Check if series length is power of 2 (optimal for FFT)
SELECT
    COUNT(*) as n_obs,
    CAST(LOG(2, COUNT(*)) AS INTEGER) as log2_n,
    POWER(2, CAST(LOG(2, COUNT(*)) AS INTEGER)) as nearest_power_of_2,
    CASE
        WHEN COUNT(*) = POWER(2, CAST(LOG(2, COUNT(*)) AS INTEGER)) THEN 'Optimal - Power of 2'
        ELSE 'Suboptimal - Consider padding to next power of 2'
    END as fft_efficiency
FROM {database}.dfft_input;

-- Remove mean (de-trending for FFT)
DROP TABLE IF EXISTS {database}.dfft_input_centered;
CREATE MULTISET TABLE {database}.dfft_input_centered AS (
    SELECT
        sequence_id,
        time_stamp,
        value_col - (SELECT AVG(value_col) FROM {database}.dfft_input) as centered_value
    FROM {database}.dfft_input
) WITH DATA;

-- Readiness check
SELECT
    'TD_DFFT Preprocessing Status' as status_type,
    COUNT(*) as n_observations,
    CASE
        WHEN COUNT(*) >= 16 THEN 'READY FOR TD_DFFT'
        WHEN COUNT(*) >= 8 THEN 'WARNING - Short series for FFT'
        ELSE 'FAIL - Too few observations (<8)'
    END as readiness
FROM {database}.dfft_input;
-- =====================================================
