-- =====================================================
-- TD_Attribution - Attribution Diagnostics
-- =====================================================

-- Top channels by attribution credit
SELECT channel, SUM(attribution_credit) as total_credit,
    COUNT(*) as touchpoint_count,
    AVG(attribution_credit) as avg_credit_per_touchpoint,
    CAST(SUM(attribution_credit) * 100.0 / SUM(SUM(attribution_credit)) OVER() AS DECIMAL(5,2)) as credit_share_pct
FROM {database}.attribution_output
GROUP BY channel
ORDER BY total_credit DESC;

-- Attribution by conversion path position
SELECT
    CASE
        WHEN touchpoint_position = 1 THEN 'First Touch'
        WHEN touchpoint_position = max_position THEN 'Last Touch'
        ELSE 'Mid-Journey'
    END as position_type,
    SUM(attribution_credit) as total_credit,
    COUNT(*) as touchpoint_count
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY {customer_id_column} ORDER BY {timestamp_column}) as touchpoint_position,
           MAX(ROW_NUMBER()) OVER (PARTITION BY {customer_id_column} ORDER BY {timestamp_column}) as max_position
    FROM {database}.attribution_output
) t
GROUP BY 1;

-- Customer journey analysis
SELECT {customer_id_column} as customer, COUNT(*) as journey_length,
    STRING_AGG(channel, ' -> ') WITHIN GROUP (ORDER BY {timestamp_column}) as journey_path,
    SUM(attribution_credit) as total_attribution
FROM {database}.attribution_output
GROUP BY {customer_id_column}
ORDER BY total_attribution DESC
LIMIT 20;

-- Time-to-conversion analysis
SELECT
    CASE
        WHEN CAST((MAX({timestamp_column}) - MIN({timestamp_column})) DAY(4) TO SECOND AS INTERVAL DAY(4) TO SECOND) <= INTERVAL '1' DAY THEN '0-1 day'
        WHEN CAST((MAX({timestamp_column}) - MIN({timestamp_column})) DAY(4) TO SECOND AS INTERVAL DAY(4) TO SECOND) <= INTERVAL '7' DAY THEN '1-7 days'
        WHEN CAST((MAX({timestamp_column}) - MIN({timestamp_column})) DAY(4) TO SECOND AS INTERVAL DAY(4) TO SECOND) <= INTERVAL '30' DAY THEN '7-30 days'
        ELSE '> 30 days'
    END as journey_duration,
    COUNT(DISTINCT {customer_id_column}) as customers,
    AVG(SUM(attribution_credit)) as avg_attribution
FROM {database}.attribution_output
WHERE {conversion_flag_column} = 1
GROUP BY {customer_id_column}
GROUP BY 1;

-- =====================================================
