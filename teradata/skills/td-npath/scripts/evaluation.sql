-- =====================================================
-- TD_nPath - Path Pattern Evaluation
-- =====================================================

SELECT 'Path Coverage' as metric_name,
    COUNT(*) as total_paths_found,
    COUNT(DISTINCT entity_id) as entities_with_pattern,
    (SELECT COUNT(DISTINCT {entity_id_column}) FROM {database}.npath_input) as total_entities,
    CAST(COUNT(DISTINCT entity_id) * 100.0 / (SELECT COUNT(DISTINCT {entity_id_column}) FROM {database}.npath_input) AS DECIMAL(5,2)) as coverage_pct
FROM {database}.npath_output;

SELECT 'Path Metrics' as metric_name,
    AVG(event_count_in_path) as avg_events_per_path,
    AVG(CAST((path_end - path_start) SECOND(10,0) AS INTEGER) / 60) as avg_duration_minutes,
    AVG(total_value) as avg_path_value
FROM {database}.npath_output;

SELECT 'Path Quality' as metric_name,
    SUM(CASE WHEN event_count_in_path >= 3 THEN 1 ELSE 0 END) as meaningful_paths,
    SUM(CASE WHEN event_count_in_path < 3 THEN 1 ELSE 0 END) as short_paths,
    CAST(SUM(CASE WHEN event_count_in_path >= 3 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as quality_score_pct
FROM {database}.npath_output;

-- =====================================================
