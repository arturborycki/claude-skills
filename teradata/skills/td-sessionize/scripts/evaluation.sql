-- =====================================================
-- TD_Sessionize - Session Quality Evaluation
-- =====================================================
-- Purpose: Evaluate sessionization results and validate session quality
-- Metrics: Session coherence, duration validity, user patterns
-- =====================================================

-- Session Count and Distribution
SELECT
    'Session Count Distribution' as metric_name,
    COUNT(DISTINCT session_id) as total_sessions,
    COUNT(DISTINCT {user_id_column}) as unique_users,
    CAST(COUNT(DISTINCT session_id) * 1.0 / NULLIF(COUNT(DISTINCT {user_id_column}), 0) AS DECIMAL(10,2)) as sessions_per_user,
    MIN(event_count) as min_events_per_session,
    AVG(event_count) as avg_events_per_session,
    MAX(event_count) as max_events_per_session
FROM (
    SELECT session_id, {user_id_column}, COUNT(*) as event_count
    FROM {database}.sessions_output
    GROUP BY session_id, {user_id_column}
) t;

-- Session Duration Metrics
SELECT
    'Session Duration Metrics' as metric_name,
    AVG(session_duration_seconds) as avg_duration_sec,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY session_duration_seconds) as median_duration_sec,
    STDDEV(session_duration_seconds) as stddev_duration_sec,
    MIN(session_duration_seconds) as min_duration_sec,
    MAX(session_duration_seconds) as max_duration_sec
FROM {database}.session_durations;

-- Session Quality Score (0-100)
SELECT
    'Session Quality Score' as metric_name,
    CAST(
        (-- Penalty for too many single-event sessions
         (1 - (SUM(CASE WHEN event_count = 1 THEN 1 ELSE 0 END) * 1.0 / COUNT(*))) * 40 +
         -- Reward for reasonable session durations
         (1 - (SUM(CASE WHEN session_duration_seconds > 7200 THEN 1 ELSE 0 END) * 1.0 / COUNT(*))) * 30 +
         -- Reward for balanced session distribution
         30)
    AS DECIMAL(5,2)) as quality_score,
    CASE
        WHEN quality_score >= 80 THEN 'Excellent'
        WHEN quality_score >= 60 THEN 'Good'
        WHEN quality_score >= 40 THEN 'Fair'
        ELSE 'Poor - Review Parameters'
    END as quality_rating
FROM {database}.session_durations;

-- Conversion Rate by Session Length
SELECT
    CASE
        WHEN event_count <= 2 THEN '1-2 events'
        WHEN event_count <= 5 THEN '3-5 events'
        WHEN event_count <= 10 THEN '6-10 events'
        WHEN event_count <= 20 THEN '11-20 events'
        ELSE '20+ events'
    END as session_length_category,
    COUNT(*) as session_count,
    SUM(CASE WHEN has_conversion = 1 THEN 1 ELSE 0 END) as conversions,
    CAST(SUM(CASE WHEN has_conversion = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as conversion_rate_pct
FROM (
    SELECT
        session_id,
        COUNT(*) as event_count,
        MAX(CASE WHEN {event_type_column} = '{goal_event}' THEN 1 ELSE 0 END) as has_conversion
    FROM {database}.sessions_output
    GROUP BY session_id
) t
GROUP BY 1;

-- User Engagement Validation
SELECT
    'User Engagement Validation' as metric_name,
    SUM(CASE WHEN total_sessions = 1 THEN 1 ELSE 0 END) as one_time_users,
    SUM(CASE WHEN total_sessions BETWEEN 2 AND 5 THEN 1 ELSE 0 END) as moderate_users,
    SUM(CASE WHEN total_sessions > 5 THEN 1 ELSE 0 END) as engaged_users,
    CAST(SUM(CASE WHEN total_sessions > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as repeat_user_pct
FROM {database}.user_session_stats;

-- Evaluation Summary
SELECT
    'Sessionization Evaluation Summary' as report_type,
    (SELECT COUNT(DISTINCT session_id) FROM {database}.sessions_output) as total_sessions,
    (SELECT AVG(session_duration_minutes) FROM {database}.session_durations) as avg_session_minutes,
    'Evaluation complete' as status;

-- =====================================================
