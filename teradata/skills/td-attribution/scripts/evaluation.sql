-- =====================================================
-- TD_Attribution - Model Evaluation
-- =====================================================

SELECT 'Attribution Coverage' as metric_name,
    COUNT(DISTINCT channel) as channels_receiving_credit,
    (SELECT COUNT(DISTINCT {channel_column}) FROM {database}.attribution_input) as total_channels,
    SUM(attribution_credit) as total_credits_assigned,
    SUM(CASE WHEN {conversion_flag_column} = 1 THEN {conversion_value_column} ELSE 0 END) as total_conversion_value
FROM {database}.attribution_output;

SELECT 'Channel Performance' as metric_name,
    channel,
    SUM(attribution_credit) as total_credit,
    COUNT(DISTINCT {customer_id_column}) as unique_customers,
    CAST(SUM(attribution_credit) * 100.0 / SUM(SUM(attribution_credit)) OVER() AS DECIMAL(5,2)) as credit_share_pct
FROM {database}.attribution_output
GROUP BY channel
ORDER BY total_credit DESC;

SELECT 'Attribution Quality' as metric_name,
    SUM(CASE WHEN attribution_credit > 0 THEN 1 ELSE 0 END) as touchpoints_with_credit,
    COUNT(*) as total_touchpoints,
    CAST(SUM(CASE WHEN attribution_credit > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as credit_coverage_pct
FROM {database}.attribution_output;

-- =====================================================
