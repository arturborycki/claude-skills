-- UAF Data Preparation for TD_WINDOW
-- Signal windowing for spectral analysis and leakage reduction

-- Validate signal for windowing
SELECT
    'Window Data Prep' as Stage,
    COUNT(*) as TotalSamples,
    POWER(2, CEILING(LOG(2, COUNT(*)))) as RecommendedWindowSize,
    MIN({TIMESTAMP_COLUMN}) as SignalStart,
    MAX({TIMESTAMP_COLUMN}) as SignalEnd
FROM {USER_DATABASE}.{USER_TABLE};

-- Check edge discontinuity (spectral leakage risk)
DROP TABLE IF EXISTS edge_discontinuity_check;
CREATE MULTISET TABLE edge_discontinuity_check AS (
    SELECT
        ABS(first_val - last_val) as EdgeDiscontinuity,
        signal_range,
        ABS(first_val - last_val) / NULLIFZERO(signal_range) * 100 as DiscontinuityPct,
        CASE
            WHEN ABS(first_val - last_val) / NULLIFZERO(signal_range) > 0.5 THEN 'HIGH - Strong windowing needed'
            WHEN ABS(first_val - last_val) / NULLIFZERO(signal_range) > 0.2 THEN 'MEDIUM - Windowing recommended'
            ELSE 'LOW - Minimal windowing needed'
        END as LeakageRisk
    FROM (
        SELECT
            FIRST_VALUE({VALUE_COLUMNS}) OVER (ORDER BY {TIMESTAMP_COLUMN}) as first_val,
            LAST_VALUE({VALUE_COLUMNS}) OVER (ORDER BY {TIMESTAMP_COLUMN} ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as last_val,
            MAX({VALUE_COLUMNS}) - MIN({VALUE_COLUMNS}) as signal_range
        FROM {USER_DATABASE}.{USER_TABLE}
        GROUP BY 1
    ) t
) WITH DATA;

SELECT * FROM edge_discontinuity_check;

DROP TABLE IF EXISTS uaf_window_prepared;
CREATE MULTISET TABLE uaf_window_prepared AS (
    SELECT
        {TIMESTAMP_COLUMN} as time_index,
        {VALUE_COLUMNS} as signal_value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as sample_id
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {VALUE_COLUMNS} IS NOT NULL
) WITH DATA;

/*
WINDOW FUNCTION CHARACTERISTICS:
- Rectangular: No attenuation, maximum leakage
- Hamming: Good sidelobe rejection, moderate resolution
- Hanning: Better sidelobe rejection than Hamming
- Blackman: Excellent sidelobe rejection, wider main lobe
- Kaiser: Adjustable tradeoff between resolution and leakage
*/
