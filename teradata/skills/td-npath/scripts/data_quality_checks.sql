-- =====================================================
-- TD_nPath - Data Quality Checks
-- =====================================================

SELECT 'Completeness' as check_name,
    COUNT(*) as total_events,
    SUM(CASE WHEN {entity_id_column} IS NULL THEN 1 ELSE 0 END) as null_entities,
    SUM(CASE WHEN {timestamp_column} IS NULL THEN 1 ELSE 0 END) as null_timestamps,
    SUM(CASE WHEN {event_state_column} IS NULL THEN 1 ELSE 0 END) as null_states,
    CASE WHEN SUM(CASE WHEN {entity_id_column} IS NULL OR {timestamp_column} IS NULL OR {event_state_column} IS NULL THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM {database}.{input_table};

SELECT 'Sequence Integrity' as check_name,
    COUNT(DISTINCT {entity_id_column}) as unique_entities,
    AVG(event_count) as avg_events_per_entity,
    MIN(event_count) as min_events,
    MAX(event_count) as max_events
FROM (SELECT {entity_id_column}, COUNT(*) as event_count FROM {database}.{input_table} GROUP BY {entity_id_column}) t;

SELECT 'State Variety' as check_name,
    COUNT(DISTINCT {event_state_column}) as unique_states,
    CASE WHEN COUNT(DISTINCT {event_state_column}) >= 2 THEN 'PASS' ELSE 'FAIL' END as status
FROM {database}.{input_table};

-- =====================================================
