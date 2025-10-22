-- =====================================================
-- TD_nPath - Data Preprocessing
-- =====================================================
-- Purpose: Prepare sequential event data for path analysis
-- Input: Raw event sequences with state/action information
-- Output: Clean, ordered sequences ready for TD_nPath pattern matching
-- =====================================================

-- Basic profiling
SELECT
    'Event Sequence Profile' as profile_section,
    COUNT(*) as total_events,
    COUNT(DISTINCT {entity_id_column}) as unique_entities,
    COUNT(DISTINCT {event_state_column}) as unique_states,
    MIN({timestamp_column}) as first_event,
    MAX({timestamp_column}) as last_event
FROM {database}.{raw_events_table};

-- Validate sequence ordering
SELECT
    {entity_id_column},
    COUNT(*) as event_count,
    MIN({timestamp_column}) as first_event_time,
    MAX({timestamp_column}) as last_event_time,
    COUNT(DISTINCT {event_state_column}) as distinct_states_in_sequence
FROM {database}.{raw_events_table}
GROUP BY {entity_id_column}
ORDER BY event_count DESC;

-- State distribution analysis
SELECT
    {event_state_column} as event_state,
    COUNT(*) as occurrence_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    COUNT(DISTINCT {entity_id_column}) as unique_entities
FROM {database}.{raw_events_table}
GROUP BY {event_state_column}
ORDER BY occurrence_count DESC;

-- Create cleaned sequence table
DROP TABLE IF EXISTS {database}.npath_events_clean;
CREATE MULTISET TABLE {database}.npath_events_clean AS (
    SELECT DISTINCT
        {entity_id_column},
        {timestamp_column},
        {event_state_column},
        {value_column},
        ROW_NUMBER() OVER (
            PARTITION BY {entity_id_column}
            ORDER BY {timestamp_column}
        ) as sequence_position,
        CAST(({timestamp_column} - LAG({timestamp_column}) OVER (
            PARTITION BY {entity_id_column}
            ORDER BY {timestamp_column}
        )) SECOND(10,0) AS INTEGER) as seconds_since_prev_event
    FROM {database}.{raw_events_table}
    WHERE
        {timestamp_column} IS NOT NULL
        AND {entity_id_column} IS NOT NULL
        AND {event_state_column} IS NOT NULL
) WITH DATA PRIMARY INDEX ({entity_id_column});

-- Transition matrix analysis
SELECT
    current_state,
    next_state,
    COUNT(*) as transition_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY current_state) AS DECIMAL(5,2)) as transition_pct
FROM (
    SELECT
        {event_state_column} as current_state,
        LEAD({event_state_column}) OVER (
            PARTITION BY {entity_id_column}
            ORDER BY {timestamp_column}
        ) as next_state
    FROM {database}.npath_events_clean
) t
WHERE next_state IS NOT NULL
GROUP BY current_state, next_state
ORDER BY current_state, transition_count DESC;

-- Prepare final nPath input table
DROP TABLE IF EXISTS {database}.npath_input;
CREATE MULTISET TABLE {database}.npath_input AS (
    SELECT
        {entity_id_column},
        {timestamp_column},
        {event_state_column},
        {value_column},
        sequence_position
    FROM {database}.npath_events_clean
) WITH DATA PRIMARY INDEX ({entity_id_column});

COLLECT STATISTICS ON {database}.npath_input COLUMN ({entity_id_column});
COLLECT STATISTICS ON {database}.npath_input COLUMN ({event_state_column});

-- Preprocessing summary
SELECT
    'nPath Preprocessing Summary' as summary_section,
    (SELECT COUNT(*) FROM {database}.{raw_events_table}) as raw_event_count,
    (SELECT COUNT(*) FROM {database}.npath_input) as clean_event_count,
    (SELECT COUNT(DISTINCT {entity_id_column}) FROM {database}.npath_input) as unique_entities,
    'Data ready for path analysis' as status;

-- =====================================================
