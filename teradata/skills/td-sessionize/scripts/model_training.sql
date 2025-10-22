-- =====================================================
-- TD_Sessionize - Session Definition and Execution
-- =====================================================
-- Purpose: Apply sessionization logic to event sequences
-- Input: Preprocessed event data with timestamps
-- Output: Sessions with session IDs and metadata
-- =====================================================

-- =====================================================
-- 1. VERIFY INPUT DATA
-- =====================================================

-- Check preprocessed data exists and is valid
SELECT
    COUNT(*) as total_events,
    COUNT(DISTINCT {user_id_column}) as unique_users,
    MIN({timestamp_column}) as earliest_event,
    MAX({timestamp_column}) as latest_event
FROM {database}.sessionize_input;

-- =====================================================
-- 2. BASIC SESSIONIZATION (Time-based Timeout)
-- =====================================================

-- Apply TD_Sessionize with timeout parameter
-- Timeout defines max inactivity period before new session
DROP TABLE IF EXISTS {database}.sessions_output;
CREATE MULTISET TABLE {database}.sessions_output AS (
    SELECT * FROM TD_Sessionize (
        ON {database}.sessionize_input PARTITION BY {user_id_column} ORDER BY {timestamp_column}
        USING
        TimeColumn ('{timestamp_column}')
        TimeOut ({timeout_seconds})  -- e.g., 1800 for 30 minutes
        ClickLag ({click_lag_column})  -- Optional: output time since previous click
    ) AS dt
) WITH DATA PRIMARY INDEX ({user_id_column}, session_id);

-- =====================================================
-- 3. SESSION SUMMARY STATISTICS
-- =====================================================

-- Basic session metrics
SELECT
    'Session Statistics' as metric_type,
    COUNT(DISTINCT session_id) as total_sessions,
    COUNT(DISTINCT {user_id_column}) as unique_users,
    CAST(COUNT(DISTINCT session_id) * 1.0 / COUNT(DISTINCT {user_id_column}) AS DECIMAL(10,2)) as avg_sessions_per_user,
    COUNT(*) as total_events,
    CAST(COUNT(*) * 1.0 / COUNT(DISTINCT session_id) AS DECIMAL(10,2)) as avg_events_per_session
FROM {database}.sessions_output;

-- =====================================================
-- 4. SESSION DURATION ANALYSIS
-- =====================================================

-- Calculate session duration for each session
DROP TABLE IF EXISTS {database}.session_durations;
CREATE MULTISET TABLE {database}.session_durations AS (
    SELECT
        {user_id_column},
        session_id,
        COUNT(*) as event_count,
        COUNT(DISTINCT {event_type_column}) as distinct_event_types,
        MIN({timestamp_column}) as session_start,
        MAX({timestamp_column}) as session_end,
        CAST((MAX({timestamp_column}) - MIN({timestamp_column})) SECOND(10,0) AS INTEGER) as session_duration_seconds,
        CAST(CAST((MAX({timestamp_column}) - MIN({timestamp_column})) SECOND(10,0) AS INTEGER) / 60.0 AS DECIMAL(10,2)) as session_duration_minutes
    FROM {database}.sessions_output
    GROUP BY {user_id_column}, session_id
) WITH DATA PRIMARY INDEX ({user_id_column}, session_id);

-- Session duration distribution
SELECT
    CASE
        WHEN session_duration_seconds = 0 THEN '0 sec (Single Event)'
        WHEN session_duration_seconds <= 60 THEN '0-1 min'
        WHEN session_duration_seconds <= 300 THEN '1-5 min'
        WHEN session_duration_seconds <= 600 THEN '5-10 min'
        WHEN session_duration_seconds <= 1800 THEN '10-30 min'
        WHEN session_duration_seconds <= 3600 THEN '30-60 min'
        ELSE '> 1 hour'
    END as duration_range,
    COUNT(*) as session_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    AVG(event_count) as avg_events_in_range
FROM {database}.session_durations
GROUP BY 1
ORDER BY
    CASE
        WHEN session_duration_seconds = 0 THEN 1
        WHEN session_duration_seconds <= 60 THEN 2
        WHEN session_duration_seconds <= 300 THEN 3
        WHEN session_duration_seconds <= 600 THEN 4
        WHEN session_duration_seconds <= 1800 THEN 5
        WHEN session_duration_seconds <= 3600 THEN 6
        ELSE 7
    END;

-- =====================================================
-- 5. USER SESSION PATTERNS
-- =====================================================

-- User-level session statistics
DROP TABLE IF EXISTS {database}.user_session_stats;
CREATE MULTISET TABLE {database}.user_session_stats AS (
    SELECT
        {user_id_column},
        COUNT(DISTINCT session_id) as total_sessions,
        SUM(event_count) as total_events,
        AVG(event_count) as avg_events_per_session,
        AVG(session_duration_seconds) as avg_session_duration_seconds,
        MIN(session_start) as first_session_start,
        MAX(session_end) as last_session_end,
        CAST((MAX(session_end) - MIN(session_start)) DAY(4) TO SECOND AS INTERVAL DAY(4) TO SECOND) as user_lifetime
    FROM {database}.session_durations
    GROUP BY {user_id_column}
) WITH DATA PRIMARY INDEX ({user_id_column});

-- User engagement segments
SELECT
    CASE
        WHEN total_sessions = 1 THEN 'Single Session'
        WHEN total_sessions <= 3 THEN 'Low Engagement (2-3)'
        WHEN total_sessions <= 10 THEN 'Medium Engagement (4-10)'
        WHEN total_sessions <= 30 THEN 'High Engagement (11-30)'
        ELSE 'Power Users (>30)'
    END as engagement_segment,
    COUNT(*) as user_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as user_percentage,
    AVG(total_sessions) as avg_sessions,
    AVG(total_events) as avg_total_events
FROM {database}.user_session_stats
GROUP BY 1
ORDER BY
    CASE
        WHEN total_sessions = 1 THEN 1
        WHEN total_sessions <= 3 THEN 2
        WHEN total_sessions <= 10 THEN 3
        WHEN total_sessions <= 30 THEN 4
        ELSE 5
    END;

-- =====================================================
-- 6. INTER-SESSION GAPS
-- =====================================================

-- Analyze time between sessions for repeat users
WITH session_gaps AS (
    SELECT
        {user_id_column},
        session_id,
        session_start,
        LAG(session_end) OVER (PARTITION BY {user_id_column} ORDER BY session_start) as prev_session_end,
        CAST((session_start - LAG(session_end) OVER (
            PARTITION BY {user_id_column}
            ORDER BY session_start
        )) SECOND(10,0) AS INTEGER) as gap_seconds
    FROM {database}.session_durations
)
SELECT
    CASE
        WHEN gap_seconds <= 3600 THEN '0-1 hour'
        WHEN gap_seconds <= 86400 THEN '1-24 hours'
        WHEN gap_seconds <= 259200 THEN '1-3 days'
        WHEN gap_seconds <= 604800 THEN '3-7 days'
        WHEN gap_seconds <= 2592000 THEN '1-4 weeks'
        ELSE '> 1 month'
    END as gap_range,
    COUNT(*) as gap_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    AVG(gap_seconds) as avg_gap_seconds,
    CAST(AVG(gap_seconds) / 3600.0 AS DECIMAL(10,2)) as avg_gap_hours
FROM session_gaps
WHERE gap_seconds IS NOT NULL
GROUP BY 1
ORDER BY avg_gap_seconds;

-- =====================================================
-- 7. EVENT SEQUENCE WITHIN SESSIONS
-- =====================================================

-- Most common event sequences (first 3 events in session)
WITH session_sequences AS (
    SELECT
        {user_id_column},
        session_id,
        {event_type_column},
        {timestamp_column},
        ROW_NUMBER() OVER (
            PARTITION BY {user_id_column}, session_id
            ORDER BY {timestamp_column}
        ) as event_position
    FROM {database}.sessions_output
)
SELECT
    MAX(CASE WHEN event_position = 1 THEN {event_type_column} END) as first_event,
    MAX(CASE WHEN event_position = 2 THEN {event_type_column} END) as second_event,
    MAX(CASE WHEN event_position = 3 THEN {event_type_column} END) as third_event,
    COUNT(DISTINCT session_id) as session_count,
    CAST(COUNT(DISTINCT session_id) * 100.0 / (
        SELECT COUNT(DISTINCT session_id) FROM {database}.sessions_output
    ) AS DECIMAL(5,2)) as percentage
FROM session_sequences
WHERE event_position <= 3
GROUP BY {user_id_column}, session_id
QUALIFY ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT session_id) DESC) <= 20;

-- =====================================================
-- 8. SESSION CONVERSION/GOAL TRACKING
-- =====================================================

-- Track sessions with specific goal events
SELECT
    CASE
        WHEN SUM(CASE WHEN {event_type_column} = '{goal_event}' THEN 1 ELSE 0 END) > 0
        THEN 'Converted'
        ELSE 'Not Converted'
    END as conversion_status,
    COUNT(DISTINCT session_id) as session_count,
    CAST(COUNT(DISTINCT session_id) * 100.0 / SUM(COUNT(DISTINCT session_id)) OVER() AS DECIMAL(5,2)) as percentage,
    AVG(COUNT(*)) as avg_events_per_session
FROM {database}.sessions_output
GROUP BY {user_id_column}, session_id
GROUP BY 1;

-- =====================================================
-- 9. SESSIONIZATION SUMMARY REPORT
-- =====================================================

SELECT
    'Sessionization Summary' as report_section,
    (SELECT COUNT(*) FROM {database}.sessionize_input) as input_events,
    (SELECT COUNT(*) FROM {database}.sessions_output) as output_events,
    (SELECT COUNT(DISTINCT session_id) FROM {database}.sessions_output) as total_sessions,
    (SELECT COUNT(DISTINCT {user_id_column}) FROM {database}.sessions_output) as unique_users,
    (SELECT AVG(event_count) FROM {database}.session_durations) as avg_events_per_session,
    (SELECT AVG(session_duration_minutes) FROM {database}.session_durations) as avg_session_duration_minutes,
    (SELECT PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY session_duration_minutes)
     FROM {database}.session_durations) as median_session_duration_minutes,
    {timeout_seconds} as timeout_parameter_seconds,
    'Sessionization complete' as status;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {user_id_column} - User/visitor identifier
--    {timestamp_column} - Event timestamp column
--    {event_type_column} - Event type/action column
--    {timeout_seconds} - Inactivity timeout in seconds (e.g., 1800 for 30 min)
--    {click_lag_column} - Optional column name for click lag output
--    {goal_event} - Conversion/goal event type (e.g., 'purchase')
--
-- 2. TD_Sessionize parameters:
--    - TimeColumn: Column containing event timestamps
--    - TimeOut: Max seconds of inactivity before new session starts
--    - ClickLag: Optional output of seconds since previous event
--
-- 3. Session definition logic:
--    - New session starts after timeout period of inactivity
--    - All events for same user within timeout are in same session
--    - Session ID is automatically generated
--
-- 4. Output tables:
--    - sessions_output: All events with session IDs
--    - session_durations: Session-level aggregates
--    - user_session_stats: User-level session metrics
--
-- 5. Common timeout values:
--    - 30 minutes (1800 sec): Standard web sessions
--    - 60 minutes (3600 sec): Extended engagement
--    - 15 minutes (900 sec): Short interactions
--
-- =====================================================
