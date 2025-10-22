-- =====================================================
-- TD_nPath - Path Analysis Diagnostics
-- =====================================================

-- Top paths by value
SELECT TOP 20 entity_id, path_start, path_end, event_count_in_path, total_value,
    CAST((path_end - path_start) SECOND(10,0) AS INTEGER) / 60 as duration_minutes
FROM {database}.npath_output
ORDER BY total_value DESC;

-- Path duration distribution
SELECT
    CASE
        WHEN CAST((path_end - path_start) SECOND(10,0) AS INTEGER) <= 300 THEN '0-5 min'
        WHEN CAST((path_end - path_start) SECOND(10,0) AS INTEGER) <= 1800 THEN '5-30 min'
        ELSE '> 30 min'
    END as duration_range,
    COUNT(*) as path_count,
    AVG(total_value) as avg_value
FROM {database}.npath_output
GROUP BY 1;

-- Entities with multiple pattern matches
SELECT entity_id, COUNT(*) as pattern_match_count, SUM(total_value) as total_value
FROM {database}.npath_output
GROUP BY entity_id
HAVING COUNT(*) > 1
ORDER BY pattern_match_count DESC;

-- Pattern match frequency by hour
SELECT EXTRACT(HOUR FROM path_start) as hour, COUNT(*) as paths_started
FROM {database}.npath_output
GROUP BY EXTRACT(HOUR FROM path_start)
ORDER BY hour;

-- =====================================================
