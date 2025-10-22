-- UAF Data Preparation for TD_FILTER
-- Digital Signal Filtering - Noise reduction and signal enhancement

-- Data Quality Check
SELECT
    'Filter Data Preparation' as Stage,
    COUNT(*) as TotalSamples,
    AVG(signal_value) as Mean,
    STDDEV(signal_value) as StdDev,
    MIN(signal_value) as Min,
    MAX(signal_value) as Max
FROM {USER_DATABASE}.{USER_TABLE};

-- Sampling Rate Validation (Critical for filter design)
DROP TABLE IF EXISTS filter_sampling_analysis;
CREATE MULTISET TABLE filter_sampling_analysis AS (
    SELECT
        AVG(sample_interval) as AvgSamplingInterval_Sec,
        1.0 / AVG(sample_interval) as SamplingRate_Hz,
        (1.0 / AVG(sample_interval)) / 2.0 as NyquistFrequency_Hz,
        STDDEV(sample_interval) / AVG(sample_interval) * 100 as SamplingIrregularity_Pct
    FROM (
        SELECT
            CAST(({TIMESTAMP_COLUMN} - LAG({TIMESTAMP_COLUMN}) OVER (ORDER BY {TIMESTAMP_COLUMN})) SECOND AS FLOAT) as sample_interval
        FROM {USER_DATABASE}.{USER_TABLE}
        QUALIFY ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) > 1
    ) intervals
) WITH DATA;

SELECT
    SamplingRate_Hz,
    NyquistFrequency_Hz,
    CASE
        WHEN SamplingIrregularity_Pct < 1.0 THEN 'Uniform - Excellent for filtering'
        WHEN SamplingIrregularity_Pct < 5.0 THEN 'Nearly uniform - Good for filtering'
        ELSE 'Irregular - Resample before filtering'
    END as SamplingQuality
FROM filter_sampling_analysis;

-- Prepare data for TD_FILTER
DROP TABLE IF EXISTS uaf_filter_prepared;
CREATE MULTISET TABLE uaf_filter_prepared AS (
    SELECT
        {TIMESTAMP_COLUMN} as time_index,
        {VALUE_COLUMNS} as signal_value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as sample_id,
        -- Calculate signal statistics for filter design
        AVG({VALUE_COLUMNS}) OVER () as signal_mean,
        STDDEV({VALUE_COLUMNS}) OVER () as signal_stddev
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {VALUE_COLUMNS} IS NOT NULL
) WITH DATA;

/*
FILTER DESIGN CONSIDERATIONS:
- Lowpass: Remove high-frequency noise
- Highpass: Remove DC offset and low-frequency drift  
- Bandpass: Isolate specific frequency band
- Bandstop: Remove specific frequency interference
- Cutoff frequency must be < Nyquist frequency
- Higher filter order = sharper cutoff, more computation
*/
