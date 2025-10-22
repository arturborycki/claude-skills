-- =====================================================
-- TD_nPath - Pattern Definition and Execution
-- =====================================================
-- Purpose: Apply nPath pattern matching to event sequences
-- Pattern: Define state transition patterns to identify
-- Output: Matched paths with aggregated metrics
-- =====================================================

-- Verify input data
SELECT COUNT(*) as total_events,
       COUNT(DISTINCT {entity_id_column}) as unique_entities,
       COUNT(DISTINCT {event_state_column}) as unique_states
FROM {database}.npath_input;

-- Execute nPath with pattern definition
DROP TABLE IF EXISTS {database}.npath_output;
CREATE MULTISET TABLE {database}.npath_output AS (
    SELECT * FROM TD_nPath (
        ON {database}.npath_input PARTITION BY {entity_id_column} ORDER BY {timestamp_column}
        USING
        Mode ('NONOVERLAPPING')  -- or 'OVERLAPPING'
        Pattern ('{pattern_definition}')  -- e.g., 'A.B*.C'
        Symbols (
            {event_state_column} = '{state_A}' AS A,
            {event_state_column} = '{state_B}' AS B,
            {event_state_column} = '{state_C}' AS C
        )
        Result (
            FIRST({entity_id_column} OF A) AS entity_id,
            FIRST({timestamp_column} OF A) AS path_start,
            LAST({timestamp_column} OF C) AS path_end,
            COUNT(*) AS event_count_in_path,
            SUM({value_column}) AS total_value
        )
    ) AS dt
) WITH DATA;

-- Path summary statistics
SELECT
    'Path Statistics' as metric_type,
    COUNT(*) as total_paths_found,
    AVG(event_count_in_path) as avg_events_per_path,
    AVG(CAST((path_end - path_start) SECOND(10,0) AS INTEGER) / 60) as avg_path_duration_minutes,
    SUM(total_value) as total_aggregated_value
FROM {database}.npath_output;

-- Path distribution by duration
SELECT
    CASE
        WHEN CAST((path_end - path_start) SECOND(10,0) AS INTEGER) <= 300 THEN '0-5 min'
        WHEN CAST((path_end - path_start) SECOND(10,0) AS INTEGER) <= 1800 THEN '5-30 min'
        WHEN CAST((path_end - path_start) SECOND(10,0) AS INTEGER) <= 3600 THEN '30-60 min'
        ELSE '> 1 hour'
    END as duration_range,
    COUNT(*) as path_count,
    AVG(total_value) as avg_value
FROM {database}.npath_output
GROUP BY 1
ORDER BY path_count DESC;

-- =====================================================
