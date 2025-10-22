-- =====================================================
-- TD_Attribution - Model Comparison
-- =====================================================

-- Test 1: First-Touch Attribution
DROP TABLE IF EXISTS {database}.attribution_first_touch;
CREATE MULTISET TABLE {database}.attribution_first_touch AS (
    SELECT * FROM TD_Attribution (
        ON {database}.attribution_input PARTITION BY {customer_id_column} ORDER BY {timestamp_column}
        USING EventColumn ('{channel_column}') TimestampColumn ('{timestamp_column}')
        ConversionEventColumn ('{conversion_flag_column}') Model ('FIRST_TOUCH')
    ) AS dt
) WITH DATA;

-- Test 2: Last-Touch Attribution
DROP TABLE IF EXISTS {database}.attribution_last_touch;
CREATE MULTISET TABLE {database}.attribution_last_touch AS (
    SELECT * FROM TD_Attribution (
        ON {database}.attribution_input PARTITION BY {customer_id_column} ORDER BY {timestamp_column}
        USING EventColumn ('{channel_column}') TimestampColumn ('{timestamp_column}')
        ConversionEventColumn ('{conversion_flag_column}') Model ('LAST_TOUCH')
    ) AS dt
) WITH DATA;

-- Test 3: Linear Attribution
DROP TABLE IF EXISTS {database}.attribution_linear;
CREATE MULTISET TABLE {database}.attribution_linear AS (
    SELECT * FROM TD_Attribution (
        ON {database}.attribution_input PARTITION BY {customer_id_column} ORDER BY {timestamp_column}
        USING EventColumn ('{channel_column}') TimestampColumn ('{timestamp_column}')
        ConversionEventColumn ('{conversion_flag_column}') Model ('LINEAR')
    ) AS dt
) WITH DATA;

-- Compare Models
SELECT 'FIRST_TOUCH' as model, channel, SUM(attribution_credit) as total_credit FROM {database}.attribution_first_touch GROUP BY channel
UNION ALL
SELECT 'LAST_TOUCH' as model, channel, SUM(attribution_credit) as total_credit FROM {database}.attribution_last_touch GROUP BY channel
UNION ALL
SELECT 'LINEAR' as model, channel, SUM(attribution_credit) as total_credit FROM {database}.attribution_linear GROUP BY channel
ORDER BY model, total_credit DESC;

-- =====================================================
