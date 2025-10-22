-- =====================================================
-- TD_Sessionize - Diagnostic Queries
-- =====================================================
-- Purpose: Deep dive analysis of sessionization results
-- Focus: Patterns, anomalies, user journeys
-- =====================================================

-- Top Sessions by Event Count
SELECT TOP 20
    session_id,
    {user_id_column},
    COUNT(*) as event_count,
    MIN({timestamp_column}) as session_start,
    MAX({timestamp_column}) as session_end,
    CAST((MAX({timestamp_column}) - MIN({timestamp_column})) SECOND(10,0) AS INTEGER) / 60 as duration_minutes,
    COUNT(DISTINCT {event_type_column}) as distinct_events
FROM {database}.sessions_output
GROUP BY session_id, {user_id_column}
ORDER BY event_count DESC;

-- Session Event Sequences
SELECT
    session_id,
    STRING_AGG({event_type_column}, ' -> ') WITHIN GROUP (ORDER BY {timestamp_column}) as event_sequence
FROM (
    SELECT TOP 1000
        session_id,
        {event_type_column},
        {timestamp_column}
    FROM {database}.sessions_output
    ORDER BY session_id, {timestamp_column}
) t
GROUP BY session_id
ORDER BY session_id;

-- Hourly Session Start Distribution
SELECT
    EXTRACT(HOUR FROM session_start) as hour_of_day,
    COUNT(*) as sessions_started,
    AVG(event_count) as avg_events,
    AVG(session_duration_minutes) as avg_duration_min
FROM {database}.session_durations
GROUP BY EXTRACT(HOUR FROM session_start)
ORDER BY hour_of_day;

-- User Journey Analysis
SELECT
    {user_id_column},
    total_sessions,
    total_events,
    CAST((last_session_end - first_session_start) DAY(4) TO SECOND AS INTERVAL DAY(4) TO SECOND) as user_lifespan,
    CAST(total_events * 1.0 / total_sessions AS DECIMAL(10,2)) as avg_events_per_session
FROM {database}.user_session_stats
WHERE total_sessions > 1
ORDER BY total_sessions DESC
LIMIT 100;

-- Session Bounce Rate (single-event sessions)
SELECT
    'Bounce Rate Analysis' as metric_name,
    SUM(CASE WHEN event_count = 1 THEN 1 ELSE 0 END) as bounced_sessions,
    COUNT(*) as total_sessions,
    CAST(SUM(CASE WHEN event_count = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as bounce_rate_pct
FROM {database}.session_durations;

-- Most Common Event Combinations
SELECT
    event_type_1,
    event_type_2,
    COUNT(*) as occurrence_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM (
    SELECT
        session_id,
        {event_type_column} as event_type_1,
        LEAD({event_type_column}) OVER (PARTITION BY session_id ORDER BY {timestamp_column}) as event_type_2
    FROM {database}.sessions_output
) t
WHERE event_type_2 IS NOT NULL
GROUP BY event_type_1, event_type_2
ORDER BY occurrence_count DESC
LIMIT 20;

-- Diagnostic Summary
SELECT
    'Sessionization Diagnostic Summary' as report_type,
    (SELECT COUNT(DISTINCT session_id) FROM {database}.sessions_output) as total_sessions,
    (SELECT COUNT(DISTINCT {user_id_column}) FROM {database}.sessions_output) as unique_users,
    'Diagnostics complete' as status;

-- =====================================================
