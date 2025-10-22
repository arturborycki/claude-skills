-- =====================================================
-- TD_Attribution - Data Preprocessing
-- =====================================================
-- Purpose: Prepare conversion path data for attribution modeling
-- Input: Customer journey touchpoint data with conversions
-- Output: Clean conversion paths ready for TD_Attribution
-- =====================================================

-- Profile touchpoint data
SELECT 'Touchpoint Profile' as profile_section,
    COUNT(*) as total_touchpoints,
    COUNT(DISTINCT {customer_id_column}) as unique_customers,
    COUNT(DISTINCT {channel_column}) as unique_channels,
    SUM(CASE WHEN {conversion_flag_column} = 1 THEN 1 ELSE 0 END) as total_conversions
FROM {database}.{raw_touchpoints_table};

-- Analyze conversion paths
SELECT {customer_id_column}, COUNT(*) as touchpoints_before_conversion,
    MIN({timestamp_column}) as first_touchpoint,
    MAX({timestamp_column}) as conversion_time,
    SUM({conversion_value_column}) as total_conversion_value
FROM {database}.{raw_touchpoints_table}
WHERE {conversion_flag_column} = 1
GROUP BY {customer_id_column}
ORDER BY touchpoints_before_conversion DESC;

-- Channel distribution
SELECT {channel_column} as channel,
    COUNT(*) as touchpoint_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    SUM(CASE WHEN {conversion_flag_column} = 1 THEN 1 ELSE 0 END) as conversions
FROM {database}.{raw_touchpoints_table}
GROUP BY {channel_column}
ORDER BY touchpoint_count DESC;

-- Create cleaned attribution input
DROP TABLE IF EXISTS {database}.attribution_events_clean;
CREATE MULTISET TABLE {database}.attribution_events_clean AS (
    SELECT DISTINCT
        {customer_id_column},
        {timestamp_column},
        {channel_column},
        {conversion_flag_column},
        {conversion_value_column},
        ROW_NUMBER() OVER (PARTITION BY {customer_id_column} ORDER BY {timestamp_column}) as touchpoint_sequence
    FROM {database}.{raw_touchpoints_table}
    WHERE {timestamp_column} IS NOT NULL
        AND {customer_id_column} IS NOT NULL
        AND {channel_column} IS NOT NULL
) WITH DATA PRIMARY INDEX ({customer_id_column});

-- Prepare final attribution input
DROP TABLE IF EXISTS {database}.attribution_input;
CREATE MULTISET TABLE {database}.attribution_input AS (
    SELECT {customer_id_column}, {timestamp_column}, {channel_column},
           {conversion_flag_column}, {conversion_value_column}
    FROM {database}.attribution_events_clean
) WITH DATA PRIMARY INDEX ({customer_id_column});

COLLECT STATISTICS ON {database}.attribution_input COLUMN ({customer_id_column});
COLLECT STATISTICS ON {database}.attribution_input COLUMN ({channel_column});

SELECT 'Attribution Preprocessing Summary' as summary,
    (SELECT COUNT(*) FROM {database}.attribution_input) as clean_touchpoints,
    (SELECT COUNT(DISTINCT {customer_id_column}) FROM {database}.attribution_input) as unique_customers,
    'Data ready for attribution' as status;

-- =====================================================
