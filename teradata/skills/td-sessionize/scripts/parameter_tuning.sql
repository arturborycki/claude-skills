-- =====================================================
-- TD_Sessionize - Parameter Tuning
-- =====================================================
-- Purpose: Optimize timeout parameter for sessionization
-- Method: Test multiple timeout values and compare results
-- =====================================================

-- Test 1: 15-minute timeout (900 seconds)
DROP TABLE IF EXISTS {database}.sessions_15min;
CREATE MULTISET TABLE {database}.sessions_15min AS (
    SELECT * FROM TD_Sessionize (
        ON {database}.sessionize_input PARTITION BY {user_id_column} ORDER BY {timestamp_column}
        USING
        TimeColumn ('{timestamp_column}')
        TimeOut (900)
    ) AS dt
) WITH DATA;

-- Test 2: 30-minute timeout (1800 seconds) - BASELINE
DROP TABLE IF EXISTS {database}.sessions_30min;
CREATE MULTISET TABLE {database}.sessions_30min AS (
    SELECT * FROM TD_Sessionize (
        ON {database}.sessionize_input PARTITION BY {user_id_column} ORDER BY {timestamp_column}
        USING
        TimeColumn ('{timestamp_column}')
        TimeOut (1800)
    ) AS dt
) WITH DATA;

-- Test 3: 60-minute timeout (3600 seconds)
DROP TABLE IF EXISTS {database}.sessions_60min;
CREATE MULTISET TABLE {database}.sessions_60min AS (
    SELECT * FROM TD_Sessionize (
        ON {database}.sessionize_input PARTITION BY {user_id_column} ORDER BY {timestamp_column}
        USING
        TimeColumn ('{timestamp_column}')
        TimeOut (3600)
    ) AS dt
) WITH DATA;

-- Compare Results
SELECT
    '15-minute' as timeout_setting,
    900 as timeout_seconds,
    COUNT(DISTINCT session_id) as total_sessions,
    CAST(COUNT(*) * 1.0 / COUNT(DISTINCT session_id) AS DECIMAL(10,2)) as avg_events_per_session,
    CAST(AVG(CAST((MAX({timestamp_column}) - MIN({timestamp_column})) SECOND(10,0) AS INTEGER)) / 60 AS DECIMAL(10,2)) as avg_session_duration_min
FROM (
    SELECT session_id, {timestamp_column}
    FROM {database}.sessions_15min
) t
GROUP BY session_id

UNION ALL

SELECT
    '30-minute' as timeout_setting,
    1800 as timeout_seconds,
    COUNT(DISTINCT session_id) as total_sessions,
    CAST(COUNT(*) * 1.0 / COUNT(DISTINCT session_id) AS DECIMAL(10,2)) as avg_events_per_session,
    CAST(AVG(CAST((MAX({timestamp_column}) - MIN({timestamp_column})) SECOND(10,0) AS INTEGER)) / 60 AS DECIMAL(10,2)) as avg_session_duration_min
FROM (
    SELECT session_id, {timestamp_column}
    FROM {database}.sessions_30min
) t
GROUP BY session_id

UNION ALL

SELECT
    '60-minute' as timeout_setting,
    3600 as timeout_seconds,
    COUNT(DISTINCT session_id) as total_sessions,
    CAST(COUNT(*) * 1.0 / COUNT(DISTINCT session_id) AS DECIMAL(10,2)) as avg_events_per_session,
    CAST(AVG(CAST((MAX({timestamp_column}) - MIN({timestamp_column})) SECOND(10,0) AS INTEGER)) / 60 AS DECIMAL(10,2)) as avg_session_duration_min
FROM (
    SELECT session_id, {timestamp_column}
    FROM {database}.sessions_60min
) t
GROUP BY session_id

ORDER BY timeout_seconds;

-- Recommendation Logic
SELECT
    'Parameter Tuning Recommendation' as report_type,
    CASE
        WHEN (SELECT COUNT(DISTINCT session_id) FROM {database}.sessions_30min) <
             (SELECT COUNT(DISTINCT session_id) FROM {database}.sessions_15min) * 0.7
        THEN '15-minute timeout recommended - High user activity'
        WHEN (SELECT COUNT(DISTINCT session_id) FROM {database}.sessions_60min) >
             (SELECT COUNT(DISTINCT session_id) FROM {database}.sessions_30min) * 1.3
        THEN '60-minute timeout recommended - Longer sessions'
        ELSE '30-minute timeout recommended - Standard behavior'
    END as recommendation;

-- =====================================================
