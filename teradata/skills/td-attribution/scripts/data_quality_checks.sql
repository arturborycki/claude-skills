-- =====================================================
-- TD_Attribution - Data Quality Checks
-- =====================================================

SELECT 'Completeness' as check_name,
    COUNT(*) as total_touchpoints,
    SUM(CASE WHEN {customer_id_column} IS NULL THEN 1 ELSE 0 END) as null_customers,
    SUM(CASE WHEN {timestamp_column} IS NULL THEN 1 ELSE 0 END) as null_timestamps,
    SUM(CASE WHEN {channel_column} IS NULL THEN 1 ELSE 0 END) as null_channels,
    CASE WHEN SUM(CASE WHEN {customer_id_column} IS NULL OR {timestamp_column} IS NULL OR {channel_column} IS NULL THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM {database}.{input_table};

SELECT 'Conversion Coverage' as check_name,
    COUNT(DISTINCT {customer_id_column}) as total_customers,
    SUM(CASE WHEN {conversion_flag_column} = 1 THEN 1 ELSE 0 END) as conversions,
    CAST(SUM(CASE WHEN {conversion_flag_column} = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT {customer_id_column}) AS DECIMAL(5,2)) as conversion_rate_pct
FROM {database}.{input_table};

SELECT 'Channel Variety' as check_name,
    COUNT(DISTINCT {channel_column}) as unique_channels,
    CASE WHEN COUNT(DISTINCT {channel_column}) >= 2 THEN 'PASS' ELSE 'WARNING' END as status
FROM {database}.{input_table};

-- =====================================================
