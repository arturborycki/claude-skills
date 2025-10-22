-- =====================================================
-- TD_Attribution - Attribution Model Execution
-- =====================================================
-- Purpose: Apply attribution modeling to conversion paths
-- Models: First-touch, Last-touch, Linear, U-shaped, Time-decay
-- Output: Attribution credits per channel/touchpoint
-- =====================================================

-- Verify input data
SELECT COUNT(*) as total_touchpoints,
       COUNT(DISTINCT {customer_id_column}) as unique_customers,
       SUM(CASE WHEN {conversion_flag_column} = 1 THEN 1 ELSE 0 END) as total_conversions
FROM {database}.attribution_input;

-- Execute Attribution with specified model
DROP TABLE IF EXISTS {database}.attribution_output;
CREATE MULTISET TABLE {database}.attribution_output AS (
    SELECT * FROM TD_Attribution (
        ON {database}.attribution_input PARTITION BY {customer_id_column} ORDER BY {timestamp_column}
        USING
        EventColumn ('{channel_column}')
        TimestampColumn ('{timestamp_column}')
        ConversionEventColumn ('{conversion_flag_column}')
        ConversionValueColumn ('{conversion_value_column}')
        Model ('{attribution_model}')  -- Options: FIRST_TOUCH, LAST_TOUCH, LINEAR, U_SHAPED, TIME_DECAY
        WindowSize ('{window_size}')  -- e.g., '30 DAYS'
    ) AS dt
) WITH DATA;

-- Channel-level attribution summary
SELECT
    channel,
    COUNT(*) as touchpoint_count,
    SUM(attribution_credit) as total_attribution_credit,
    AVG(attribution_credit) as avg_credit_per_touchpoint,
    CAST(SUM(attribution_credit) * 100.0 / SUM(SUM(attribution_credit)) OVER() AS DECIMAL(5,2)) as credit_percentage
FROM {database}.attribution_output
GROUP BY channel
ORDER BY total_attribution_credit DESC;

-- Conversion path length distribution
SELECT
    path_length,
    COUNT(DISTINCT customer_id) as customers,
    SUM(conversion_value) as total_conversion_value,
    AVG(conversion_value) as avg_conversion_value
FROM (
    SELECT {customer_id_column} as customer_id,
           COUNT(*) as path_length,
           MAX({conversion_value_column}) as conversion_value
    FROM {database}.attribution_output
    WHERE {conversion_flag_column} = 1
    GROUP BY {customer_id_column}
) t
GROUP BY path_length
ORDER BY path_length;

-- =====================================================
