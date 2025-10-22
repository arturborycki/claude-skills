-- =====================================================
-- TD_Sessionize - Data Preprocessing
-- =====================================================
-- Purpose: Prepare event sequence data for sessionization
-- Input: Raw event/clickstream data with timestamps
-- Output: Clean, validated event sequences ready for TD_Sessionize
-- =====================================================

-- =====================================================
-- 1. BASIC DATA PROFILING
-- =====================================================

-- Check total record count and unique users/sessions
SELECT
    'Event Data Profile' as profile_section,
    COUNT(*) as total_events,
    COUNT(DISTINCT {user_id_column}) as unique_users,
    COUNT(DISTINCT {event_id_column}) as unique_events,
    MIN({timestamp_column}) as first_event_time,
    MAX({timestamp_column}) as last_event_time,
    CAST((MAX({timestamp_column}) - MIN({timestamp_column})) DAY(4) TO SECOND AS INTERVAL DAY(4) TO SECOND) as time_span
FROM {database}.{raw_events_table};

-- =====================================================
-- 2. EVENT SEQUENCE VALIDATION
-- =====================================================

-- Check for events per user distribution
SELECT
    {user_id_column},
    COUNT(*) as event_count,
    MIN({timestamp_column}) as first_event,
    MAX({timestamp_column}) as last_event,
    COUNT(DISTINCT {event_type_column}) as distinct_event_types
FROM {database}.{raw_events_table}
GROUP BY {user_id_column}
ORDER BY event_count DESC;

-- Event type distribution
SELECT
    {event_type_column} as event_type,
    COUNT(*) as event_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    COUNT(DISTINCT {user_id_column}) as unique_users
FROM {database}.{raw_events_table}
GROUP BY {event_type_column}
ORDER BY event_count DESC;

-- =====================================================
-- 3. TIMESTAMP VALIDATION AND ORDERING
-- =====================================================

-- Check for NULL or invalid timestamps
SELECT
    COUNT(*) as total_records,
    SUM(CASE WHEN {timestamp_column} IS NULL THEN 1 ELSE 0 END) as null_timestamps,
    SUM(CASE WHEN {user_id_column} IS NULL THEN 1 ELSE 0 END) as null_user_ids,
    CAST(SUM(CASE WHEN {timestamp_column} IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as null_timestamp_pct,
    CASE
        WHEN SUM(CASE WHEN {timestamp_column} IS NULL THEN 1 ELSE 0 END) = 0 THEN 'PASS'
        ELSE 'FAIL - Null Timestamps Found'
    END as timestamp_check
FROM {database}.{raw_events_table};

-- Check for timestamp ordering issues (out-of-order events)
WITH user_events AS (
    SELECT
        {user_id_column},
        {timestamp_column},
        LAG({timestamp_column}) OVER (PARTITION BY {user_id_column} ORDER BY {timestamp_column}) as prev_timestamp
    FROM {database}.{raw_events_table}
)
SELECT
    COUNT(*) as total_events,
    SUM(CASE WHEN prev_timestamp IS NOT NULL AND {timestamp_column} < prev_timestamp THEN 1 ELSE 0 END) as out_of_order_events,
    CAST(SUM(CASE WHEN prev_timestamp IS NOT NULL AND {timestamp_column} < prev_timestamp THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as out_of_order_pct
FROM user_events;

-- =====================================================
-- 4. CREATE CLEANED EVENT SEQUENCE TABLE
-- =====================================================

-- Remove duplicates and ensure proper ordering
DROP TABLE IF EXISTS {database}.sessionize_events_clean;
CREATE MULTISET TABLE {database}.sessionize_events_clean AS (
    SELECT DISTINCT
        {user_id_column},
        {timestamp_column},
        {event_type_column},
        {event_id_column},
        -- Add row number for sequence ordering
        ROW_NUMBER() OVER (
            PARTITION BY {user_id_column}
            ORDER BY {timestamp_column}, {event_id_column}
        ) as event_sequence_number,
        -- Calculate time since previous event (in seconds)
        CAST(
            ({timestamp_column} - LAG({timestamp_column}) OVER (
                PARTITION BY {user_id_column}
                ORDER BY {timestamp_column}
            )) SECOND(10,0) AS INTEGER
        ) as seconds_since_prev_event
    FROM {database}.{raw_events_table}
    WHERE
        {timestamp_column} IS NOT NULL
        AND {user_id_column} IS NOT NULL
        AND {event_type_column} IS NOT NULL
) WITH DATA PRIMARY INDEX ({user_id_column});

-- =====================================================
-- 5. EVENT SEQUENCE STATISTICS
-- =====================================================

-- Calculate session timing statistics
SELECT
    'Event Timing Statistics' as stat_type,
    AVG(seconds_since_prev_event) as avg_seconds_between_events,
    STDDEV(seconds_since_prev_event) as stddev_seconds_between_events,
    MIN(seconds_since_prev_event) as min_seconds_between_events,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY seconds_since_prev_event) as q1_seconds,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY seconds_since_prev_event) as median_seconds,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY seconds_since_prev_event) as q3_seconds,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY seconds_since_prev_event) as p90_seconds,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY seconds_since_prev_event) as p95_seconds,
    MAX(seconds_since_prev_event) as max_seconds_between_events
FROM {database}.sessionize_events_clean
WHERE seconds_since_prev_event IS NOT NULL;

-- =====================================================
-- 6. INACTIVITY GAP ANALYSIS (for TimeOut parameter)
-- =====================================================

-- Analyze distribution of time gaps to determine optimal timeout
SELECT
    CASE
        WHEN seconds_since_prev_event <= 60 THEN '0-1 min'
        WHEN seconds_since_prev_event <= 300 THEN '1-5 min'
        WHEN seconds_since_prev_event <= 600 THEN '5-10 min'
        WHEN seconds_since_prev_event <= 1800 THEN '10-30 min'
        WHEN seconds_since_prev_event <= 3600 THEN '30-60 min'
        WHEN seconds_since_prev_event <= 7200 THEN '1-2 hours'
        ELSE '> 2 hours'
    END as time_gap_range,
    COUNT(*) as gap_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    AVG(seconds_since_prev_event) as avg_gap_seconds
FROM {database}.sessionize_events_clean
WHERE seconds_since_prev_event IS NOT NULL
GROUP BY 1
ORDER BY
    CASE
        WHEN seconds_since_prev_event <= 60 THEN 1
        WHEN seconds_since_prev_event <= 300 THEN 2
        WHEN seconds_since_prev_event <= 600 THEN 3
        WHEN seconds_since_prev_event <= 1800 THEN 4
        WHEN seconds_since_prev_event <= 3600 THEN 5
        WHEN seconds_since_prev_event <= 7200 THEN 6
        ELSE 7
    END;

-- =====================================================
-- 7. USER ACTIVITY PATTERNS
-- =====================================================

-- User engagement metrics
SELECT
    {user_id_column},
    COUNT(*) as total_events,
    COUNT(DISTINCT {event_type_column}) as distinct_event_types,
    MIN({timestamp_column}) as first_activity,
    MAX({timestamp_column}) as last_activity,
    CAST((MAX({timestamp_column}) - MIN({timestamp_column})) SECOND(10,0) AS INTEGER) as activity_duration_seconds,
    CAST((MAX({timestamp_column}) - MIN({timestamp_column})) SECOND(10,0) AS INTEGER) / NULLIF(COUNT(*) - 1, 0) as avg_seconds_per_event
FROM {database}.sessionize_events_clean
GROUP BY {user_id_column}
HAVING COUNT(*) > 1
ORDER BY total_events DESC;

-- =====================================================
-- 8. PREPARE FINAL SESSIONIZE INPUT TABLE
-- =====================================================

-- Create optimized table for TD_Sessionize
DROP TABLE IF EXISTS {database}.sessionize_input;
CREATE MULTISET TABLE {database}.sessionize_input AS (
    SELECT
        {user_id_column},
        {timestamp_column},
        {event_type_column},
        event_sequence_number,
        seconds_since_prev_event,
        -- Add any additional columns needed for analysis
        {additional_column_1},
        {additional_column_2}
    FROM {database}.sessionize_events_clean
) WITH DATA PRIMARY INDEX ({user_id_column});

-- Collect statistics for query optimization
COLLECT STATISTICS ON {database}.sessionize_input COLUMN ({user_id_column});
COLLECT STATISTICS ON {database}.sessionize_input COLUMN ({timestamp_column});

-- =====================================================
-- 9. PREPROCESSING SUMMARY
-- =====================================================

SELECT
    'Preprocessing Summary' as summary_section,
    (SELECT COUNT(*) FROM {database}.{raw_events_table}) as raw_event_count,
    (SELECT COUNT(*) FROM {database}.sessionize_events_clean) as clean_event_count,
    (SELECT COUNT(*) FROM {database}.{raw_events_table}) - (SELECT COUNT(*) FROM {database}.sessionize_events_clean) as removed_events,
    (SELECT COUNT(DISTINCT {user_id_column}) FROM {database}.sessionize_input) as unique_users,
    (SELECT AVG(event_count) FROM (
        SELECT COUNT(*) as event_count
        FROM {database}.sessionize_input
        GROUP BY {user_id_column}
    ) t) as avg_events_per_user,
    'Data ready for sessionization' as status;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {raw_events_table} - Raw event/clickstream table
--    {user_id_column} - User/visitor identifier
--    {timestamp_column} - Event timestamp column
--    {event_type_column} - Event type/action column
--    {event_id_column} - Unique event identifier
--    {additional_column_1}, {additional_column_2} - Additional context columns
--
-- 2. Data requirements for TD_Sessionize:
--    - User/session identifier column
--    - Timestamp column (properly ordered)
--    - Event type or action column
--    - No duplicate events
--
-- 3. Key preprocessing steps:
--    - Remove NULL timestamps and user IDs
--    - Ensure proper chronological ordering
--    - Calculate time gaps between events
--    - Analyze inactivity patterns for timeout parameter
--    - Create optimized input table with proper indexing
--
-- 4. Output table: sessionize_input
--    Ready for use with TD_Sessionize function
--
-- =====================================================
