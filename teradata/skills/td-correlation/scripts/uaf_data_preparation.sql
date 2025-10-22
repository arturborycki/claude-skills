-- UAF Data Preparation for TD_CORRELATION
-- Signal correlation analysis for similarity and delay detection

DROP TABLE IF EXISTS uaf_correlation_prepared;
CREATE MULTISET TABLE uaf_correlation_prepared AS (
    SELECT
        {TIMESTAMP_COLUMN} as time_index,
        {VALUE_COLUMN_1} as signal1_value,
        {VALUE_COLUMN_2} as signal2_value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as sample_id
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {VALUE_COLUMN_1} IS NOT NULL
    AND {VALUE_COLUMN_2} IS NOT NULL
) WITH DATA;

-- Correlation readiness check
SELECT
    'Correlation Prep' as Stage,
    COUNT(*) as TotalSamples,
    CORR(signal1_value, signal2_value) as PearsonCorrelation,
    AVG(signal1_value) as Signal1_Mean,
    AVG(signal2_value) as Signal2_Mean,
    STDDEV(signal1_value) as Signal1_StdDev,
    STDDEV(signal2_value) as Signal2_StdDev,
    CASE
        WHEN ABS(CORR(signal1_value, signal2_value)) > 0.7 THEN 'Strong correlation expected'
        WHEN ABS(CORR(signal1_value, signal2_value)) > 0.3 THEN 'Moderate correlation'
        ELSE 'Weak correlation - Check for time lag'
    END as CorrelationStrength
FROM uaf_correlation_prepared;
