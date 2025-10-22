-- UAF Data Preparation for TD_DETREND
-- Signal detrending for baseline correction and trend removal

DROP TABLE IF EXISTS uaf_detrend_prepared;
CREATE MULTISET TABLE uaf_detrend_prepared AS (
    SELECT
        {TIMESTAMP_COLUMN} as time_index,
        {VALUE_COLUMNS} as signal_value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as sample_id
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {VALUE_COLUMNS} IS NOT NULL
) WITH DATA;

-- Trend detection
DROP TABLE IF EXISTS trend_analysis;
CREATE MULTISET TABLE trend_analysis AS (
    SELECT
        'Trend Detection' as AnalysisType,
        linear_slope,
        quadratic_curvature,
        CASE
            WHEN ABS(quadratic_curvature) > ABS(linear_slope) * 0.1 THEN 'Polynomial trend detected'
            WHEN ABS(linear_slope) > stddev_value * 0.01 THEN 'Linear trend detected'
            ELSE 'Minimal trend - Detrending optional'
        END as TrendType
    FROM (
        SELECT
            REGR_SLOPE(signal_value, sample_id) as linear_slope,
            REGR_R2(signal_value, sample_id) as linear_r2,
            STDDEV(signal_value) as stddev_value,
            0.0 as quadratic_curvature  -- Simplified
        FROM uaf_detrend_prepared
    ) t
) WITH DATA;

SELECT * FROM trend_analysis;
