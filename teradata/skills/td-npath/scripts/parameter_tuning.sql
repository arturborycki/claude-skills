-- =====================================================
-- TD_nPath - Pattern and Mode Tuning
-- =====================================================

-- Test 1: NONOVERLAPPING mode
DROP TABLE IF EXISTS {database}.npath_nonoverlap;
CREATE MULTISET TABLE {database}.npath_nonoverlap AS (
    SELECT * FROM TD_nPath (
        ON {database}.npath_input PARTITION BY {entity_id_column} ORDER BY {timestamp_column}
        USING
        Mode ('NONOVERLAPPING')
        Pattern ('{pattern_definition}')
        Symbols ({symbol_definitions})
        Result ({result_columns})
    ) AS dt
) WITH DATA;

-- Test 2: OVERLAPPING mode
DROP TABLE IF EXISTS {database}.npath_overlap;
CREATE MULTISET TABLE {database}.npath_overlap AS (
    SELECT * FROM TD_nPath (
        ON {database}.npath_input PARTITION BY {entity_id_column} ORDER BY {timestamp_column}
        USING
        Mode ('OVERLAPPING')
        Pattern ('{pattern_definition}')
        Symbols ({symbol_definitions})
        Result ({result_columns})
    ) AS dt
) WITH DATA;

-- Compare Results
SELECT 'NONOVERLAPPING' as mode, COUNT(*) as paths_found, AVG(event_count_in_path) as avg_events FROM {database}.npath_nonoverlap
UNION ALL
SELECT 'OVERLAPPING' as mode, COUNT(*) as paths_found, AVG(event_count_in_path) as avg_events FROM {database}.npath_overlap
ORDER BY paths_found DESC;

-- =====================================================
