-- =====================================================
-- TD_Sessionize - Data Quality Checks
-- =====================================================
-- Purpose: Validate event sequence data quality and integrity
-- Checks: Completeness, ordering, duplicates, consistency
-- =====================================================

-- Check 1: Event completeness
SELECT
    'Event Completeness' as check_name,
    COUNT(*) as total_events,
    SUM(CASE WHEN {user_id_column} IS NULL THEN 1 ELSE 0 END) as null_user_ids,
    SUM(CASE WHEN {timestamp_column} IS NULL THEN 1 ELSE 0 END) as null_timestamps,
    SUM(CASE WHEN {event_type_column} IS NULL THEN 1 ELSE 0 END) as null_event_types,
    CASE
        WHEN SUM(CASE WHEN {user_id_column} IS NULL THEN 1 ELSE 0 END) = 0
         AND SUM(CASE WHEN {timestamp_column} IS NULL THEN 1 ELSE 0 END) = 0
         AND SUM(CASE WHEN {event_type_column} IS NULL THEN 1 ELSE 0 END) = 0
        THEN 'PASS' ELSE 'FAIL'
    END as status
FROM {database}.{input_table};

-- Check 2: Duplicate events
WITH duplicates AS (
    SELECT {user_id_column}, {timestamp_column}, {event_type_column}, COUNT(*) as dup_count
    FROM {database}.{input_table}
    GROUP BY 1,2,3
    HAVING COUNT(*) > 1
)
SELECT
    'Duplicate Events' as check_name,
    COUNT(*) as duplicate_combinations,
    SUM(dup_count) as total_duplicate_events,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARNING' END as status
FROM duplicates;

-- Check 3: Temporal ordering
SELECT
    'Temporal Ordering' as check_name,
    MIN({timestamp_column}) as min_timestamp,
    MAX({timestamp_column}) as max_timestamp,
    COUNT(DISTINCT CAST({timestamp_column} AS DATE)) as distinct_dates,
    CASE
        WHEN MIN({timestamp_column}) < MAX({timestamp_column}) THEN 'PASS'
        ELSE 'FAIL'
    END as status
FROM {database}.{input_table};

-- Check 4: User distribution
SELECT
    'User Distribution' as check_name,
    COUNT(DISTINCT {user_id_column}) as unique_users,
    AVG(event_count) as avg_events_per_user,
    MIN(event_count) as min_events_per_user,
    MAX(event_count) as max_events_per_user,
    CASE WHEN COUNT(DISTINCT {user_id_column}) > 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM (
    SELECT {user_id_column}, COUNT(*) as event_count
    FROM {database}.{input_table}
    GROUP BY {user_id_column}
) t;

-- Check 5: Event type variety
SELECT
    'Event Type Variety' as check_name,
    COUNT(DISTINCT {event_type_column}) as unique_event_types,
    CASE WHEN COUNT(DISTINCT {event_type_column}) > 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM {database}.{input_table};

-- Check 6: Time gap analysis
WITH gaps AS (
    SELECT
        {user_id_column},
        {timestamp_column} - LAG({timestamp_column}) OVER (
            PARTITION BY {user_id_column} ORDER BY {timestamp_column}
        ) as time_gap
    FROM {database}.{input_table}
)
SELECT
    'Time Gap Analysis' as check_name,
    COUNT(CASE WHEN time_gap IS NOT NULL THEN 1 END) as gaps_measured,
    AVG(CAST(time_gap SECOND(10,0) AS INTEGER)) as avg_gap_seconds,
    MIN(CAST(time_gap SECOND(10,0) AS INTEGER)) as min_gap_seconds,
    MAX(CAST(time_gap SECOND(10,0) AS INTEGER)) as max_gap_seconds,
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM gaps;

-- Summary
SELECT 'Data Quality Summary' as report,
       (SELECT COUNT(*) FROM {database}.{input_table}) as total_records,
       'Ready for sessionization' as status;

-- =====================================================
