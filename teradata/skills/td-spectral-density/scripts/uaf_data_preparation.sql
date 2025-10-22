-- UAF Data Preparation for TD_SPECTRAL_DENSITY
-- Power spectral density estimation for frequency content analysis

DROP TABLE IF EXISTS uaf_spectral_density_prepared;
CREATE MULTISET TABLE uaf_spectral_density_prepared AS (
    SELECT
        {TIMESTAMP_COLUMN} as time_index,
        {VALUE_COLUMNS} as signal_value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as sample_id,
        -- Remove mean for PSD estimation
        {VALUE_COLUMNS} - AVG({VALUE_COLUMNS}) OVER () as demeaned_signal
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {VALUE_COLUMNS} IS NOT NULL
) WITH DATA;

-- Sampling rate for PSD
SELECT
    'PSD Preparation' as Stage,
    COUNT(*) as TotalSamples,
    1.0 / AVG(sample_interval) as SamplingRate_Hz,
    (1.0 / AVG(sample_interval)) / 2.0 as MaxAnalyzableFreq_Hz
FROM (
    SELECT CAST((time_index - LAG(time_index) OVER (ORDER BY time_index)) SECOND AS FLOAT) as sample_interval
    FROM uaf_spectral_density_prepared
    QUALIFY ROW_NUMBER() OVER (ORDER BY time_index) > 1
) t;
