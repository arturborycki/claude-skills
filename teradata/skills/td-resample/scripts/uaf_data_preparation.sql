-- UAF Data Preparation for TD_RESAMPLE
-- Signal resampling and interpolation for rate conversion

DROP TABLE IF EXISTS uaf_resample_prepared;
CREATE MULTISET TABLE uaf_resample_prepared AS (
    SELECT
        {TIMESTAMP_COLUMN} as time_index,
        {VALUE_COLUMNS} as signal_value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as sample_id
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {VALUE_COLUMNS} IS NOT NULL
) WITH DATA;

-- Current sampling rate analysis
DROP TABLE IF EXISTS current_sampling_rate;
CREATE MULTISET TABLE current_sampling_rate AS (
    SELECT
        'Current Sampling' as Stage,
        COUNT(*) as TotalSamples,
        AVG(sample_interval) as AvgInterval_Sec,
        1.0 / AVG(sample_interval) as CurrentSamplingRate_Hz,
        (1.0 / AVG(sample_interval)) / 2.0 as CurrentNyquist_Hz
    FROM (
        SELECT CAST((time_index - LAG(time_index) OVER (ORDER BY time_index)) SECOND AS FLOAT) as sample_interval
        FROM uaf_resample_prepared
        QUALIFY ROW_NUMBER() OVER (ORDER BY time_index) > 1
    ) t
) WITH DATA;

SELECT * FROM current_sampling_rate;

-- Resampling targets
SELECT
    'Resampling Options' as Info,
    CurrentSamplingRate_Hz as Current_Hz,
    CurrentSamplingRate_Hz * 2 as Upsample_2x_Hz,
    CurrentSamplingRate_Hz / 2 as Downsample_2x_Hz,
    'Ensure target rate satisfies Nyquist theorem' as Warning
FROM current_sampling_rate;
