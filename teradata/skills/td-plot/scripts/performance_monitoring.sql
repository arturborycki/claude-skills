-- =====================================================
-- TD_Plot - UAF Performance Monitoring
-- =====================================================
-- Purpose: Monitor and optimize TD_Plot execution
-- Function: TD_Plot performance tracking
-- Framework: Teradata Unbounded Array Framework (UAF)
-- =====================================================

-- This script monitors UAF function execution, resource usage,
-- and optimization opportunities for production workloads

-- INSTRUCTIONS:
-- Replace {USER_DATABASE} with your database name

-- ============================================================================
-- MONITORING STAGE 1: Execution Time Tracking
-- ============================================================================

-- Create performance log table (one-time setup)
-- Uncomment and run once to create the table
/*
CREATE MULTISET TABLE {USER_DATABASE}.uaf_performance_log (
    execution_id INTEGER,
    function_name VARCHAR(100),
    database_name VARCHAR(100),
    table_name VARCHAR(100),
    start_timestamp TIMESTAMP,
    end_timestamp TIMESTAMP,
    duration_seconds DECIMAL(12,2),
    n_observations INTEGER,
    status VARCHAR(50),
    error_message VARCHAR(1000)
) PRIMARY INDEX (execution_id);

-- Create sequence for execution IDs
CREATE SEQUENCE {USER_DATABASE}.uaf_execution_seq
    AS INTEGER
    START WITH 1
    INCREMENT BY 1
    MINVALUE 1
    NO MAXVALUE
    NO CYCLE;
*/

-- Log execution start
INSERT INTO {USER_DATABASE}.uaf_performance_log (
    execution_id,
    function_name,
    database_name,
    table_name,
    start_timestamp,
    n_observations,
    status
)
SELECT
    NEXT VALUE FOR {USER_DATABASE}.uaf_execution_seq,
    'TD_Plot',
    '{USER_DATABASE}',
    'uaf_plot_input',
    CURRENT_TIMESTAMP,
    (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_plot_input),
    'RUNNING';

-- ============================================================================
-- MONITORING STAGE 2: Resource Usage Analysis
-- ============================================================================

-- Check table statistics and data distribution
SELECT
    DatabaseName,
    TableName,
    CurrentPerm as current_perm_bytes,
    CurrentPerm / 1024 / 1024 as current_perm_mb,
    PeakPerm as peak_perm_bytes,
    PeakPerm / 1024 / 1024 as peak_perm_mb,
    (PeakPerm - CurrentPerm) / 1024 / 1024 as temp_space_mb
FROM DBC.TableSize
WHERE DatabaseName = '{USER_DATABASE}'
  AND TableName IN ('uaf_plot_input', 'plot_results')
ORDER BY TableName;

-- Check data skew on primary index
SELECT
    HashAmp() as amp_number,
    COUNT(*) as row_count,
    MAX(COUNT(*)) OVER () / NULLIF(AVG(COUNT(*)) OVER (), 0) as skew_factor,
    CASE
        WHEN MAX(COUNT(*)) OVER () / NULLIF(AVG(COUNT(*)) OVER (), 0) < 1.1 THEN 'Excellent distribution (<10% skew)'
        WHEN MAX(COUNT(*)) OVER () / NULLIF(AVG(COUNT(*)) OVER (), 0) < 1.5 THEN 'Good distribution (<50% skew)'
        ELSE 'Warning: Significant data skew detected'
    END as distribution_quality
FROM {USER_DATABASE}.uaf_plot_input
GROUP BY HashAmp()
ORDER BY amp_number;

-- ============================================================================
-- MONITORING STAGE 3: Query Performance Statistics
-- ============================================================================

-- Monitor recent TD_Plot executions
SELECT
    QueryID,
    UserName,
    StartTime,
    CAST((FirstRespTime - StartTime) HOUR(4) TO SECOND(2)) as response_time,
    CAST((LastRespTime - StartTime) HOUR(4) TO SECOND(2)) as total_runtime,
    AMPCPUTime,
    TotalIOCount,
    ReqIOKB / 1024 as req_io_mb,
    UsedIOKB / 1024 as used_io_mb,
    NumResultRows
FROM DBC.QryLog
WHERE QueryText LIKE '%TD_Plot%'
  AND LogDate >= CURRENT_DATE - 7
  AND UserName = USER
ORDER BY StartTime DESC;

-- ============================================================================
-- MONITORING STAGE 4: Result Quality Metrics
-- ============================================================================

-- Analyze result quality and completeness
SELECT
    'Result Quality Analysis' as metric_category,
    (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_plot_input) as n_input_observations,
    (SELECT COUNT(*) FROM {USER_DATABASE}.plot_results) as n_output_results,
    (SELECT COUNT(*) FROM {USER_DATABASE}.plot_results WHERE result_value IS NOT NULL) as n_valid_results,
    CAST(
        (SELECT COUNT(*) FROM {USER_DATABASE}.plot_results WHERE result_value IS NOT NULL) /
        CAST((SELECT COUNT(*) FROM {USER_DATABASE}.plot_results) AS FLOAT) * 100
        AS DECIMAL(8,2)
    ) as completeness_pct,
    CASE
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.plot_results WHERE result_value IS NOT NULL) /
             CAST((SELECT COUNT(*) FROM {USER_DATABASE}.plot_results) AS FLOAT) >= 0.95
        THEN 'Excellent - High completeness (>=95%)'
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.plot_results WHERE result_value IS NOT NULL) /
             CAST((SELECT COUNT(*) FROM {USER_DATABASE}.plot_results) AS FLOAT) >= 0.80
        THEN 'Good - Acceptable completeness (>=80%)'
        ELSE 'Warning - Low completeness (<80%)'
    END as quality_assessment;

-- ============================================================================
-- MONITORING STAGE 5: Memory and Storage Optimization
-- ============================================================================

-- Analyze result table sizes
SELECT
    'Storage Analysis' as analysis_type,
    (SELECT COUNT(*) FROM {USER_DATABASE}.plot_results) as total_result_rows,
    (SELECT SUM(CurrentPerm) / 1024 / 1024
     FROM DBC.TableSize
     WHERE DatabaseName = '{USER_DATABASE}'
       AND TableName = 'plot_results') as total_size_mb,
    (SELECT SUM(CurrentPerm) / 1024 / 1024
     FROM DBC.TableSize
     WHERE DatabaseName = '{USER_DATABASE}'
       AND TableName = 'plot_results') / NULLIF((SELECT COUNT(*) FROM {USER_DATABASE}.plot_results), 0) as avg_mb_per_1000_rows;

-- Identify optimization opportunities
SELECT
    'Optimization Recommendations' as recommendation_type,
    CASE
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_plot_input) > 10000
        THEN 'Consider partitioning input table by time ranges for very large datasets'
        ELSE 'Current dataset size is optimal for single-table processing'
    END as data_partitioning,
    CASE
        WHEN (SELECT MAX(COUNT(*)) OVER () / NULLIF(AVG(COUNT(*)) OVER (), 0)
              FROM {USER_DATABASE}.uaf_plot_input
              GROUP BY HashAmp()) > 1.5
        THEN 'Review primary index to reduce data skew'
        ELSE 'Data distribution is acceptable'
    END as index_optimization,
    CASE
        WHEN (SELECT CurrentPerm / 1024 / 1024
              FROM DBC.TableSize
              WHERE DatabaseName = '{USER_DATABASE}' AND TableName = 'plot_results') > 1000
        THEN 'Consider archiving or summarizing historical results'
        ELSE 'Result table size is manageable'
    END as storage_management;

-- ============================================================================
-- MONITORING STAGE 6: Error Detection and Handling
-- ============================================================================

-- Check for potential data quality issues
SELECT
    'Data Quality Checks' as check_category,
    (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_plot_input WHERE series_value IS NULL) as null_values,
    (SELECT COUNT(*)
     FROM {USER_DATABASE}.uaf_plot_input
     WHERE ABS(series_value - (SELECT AVG(series_value) FROM {USER_DATABASE}.uaf_plot_input)) >
           3 * (SELECT STDDEV(series_value) FROM {USER_DATABASE}.uaf_plot_input)) as outliers_3sd,
    (SELECT COUNT(DISTINCT time_index) FROM {USER_DATABASE}.uaf_plot_input) as distinct_timestamps,
    (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_plot_input) as total_rows,
    CASE
        WHEN (SELECT COUNT(DISTINCT time_index) FROM {USER_DATABASE}.uaf_plot_input) =
             (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_plot_input)
        THEN 'No duplicate timestamps'
        ELSE 'Warning: Duplicate timestamps detected'
    END as timestamp_uniqueness;

-- ============================================================================
-- MONITORING STAGE 7: Execution Benchmarking
-- ============================================================================

-- Compare execution times across runs
SELECT
    execution_id,
    function_name,
    n_observations,
    duration_seconds,
    duration_seconds / NULLIF(n_observations, 0) * 1000 as seconds_per_1000_observations,
    status,
    start_timestamp,
    CASE
        WHEN duration_seconds < 10 THEN 'Fast (<10s)'
        WHEN duration_seconds < 60 THEN 'Moderate (<1min)'
        WHEN duration_seconds < 300 THEN 'Slow (<5min)'
        ELSE 'Very slow (>5min)'
    END as performance_category
FROM {USER_DATABASE}.uaf_performance_log
WHERE function_name = 'TD_Plot'
  AND status = 'COMPLETED'
ORDER BY start_timestamp DESC
LIMIT 20;

-- ============================================================================
-- MONITORING STAGE 8: Production Health Dashboard
-- ============================================================================

-- Overall UAF TD_Plot health metrics
SELECT
    'UAF Performance Dashboard' as dashboard_section,
    COUNT(*) as total_executions,
    SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) as successful_executions,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed_executions,
    CAST(AVG(CASE WHEN status = 'COMPLETED' THEN duration_seconds ELSE NULL END) AS DECIMAL(12,2)) as avg_duration_seconds,
    CAST(MIN(CASE WHEN status = 'COMPLETED' THEN duration_seconds ELSE NULL END) AS DECIMAL(12,2)) as min_duration_seconds,
    CAST(MAX(CASE WHEN status = 'COMPLETED' THEN duration_seconds ELSE NULL END) AS DECIMAL(12,2)) as max_duration_seconds,
    CAST(AVG(n_observations) AS INTEGER) as avg_observations
FROM {USER_DATABASE}.uaf_performance_log
WHERE function_name = 'TD_Plot'
  AND start_timestamp >= CURRENT_TIMESTAMP - INTERVAL '30' DAY;

-- ============================================================================
-- MONITORING STAGE 9: Update Performance Log (Post-Execution)
-- ============================================================================

-- Update execution log with completion metrics
UPDATE {USER_DATABASE}.uaf_performance_log
SET
    end_timestamp = CURRENT_TIMESTAMP,
    duration_seconds = CAST((CURRENT_TIMESTAMP - start_timestamp) SECOND(4,2) AS DECIMAL(12,2)),
    status = 'COMPLETED'
WHERE execution_id = (SELECT MAX(execution_id)
                      FROM {USER_DATABASE}.uaf_performance_log
                      WHERE function_name = 'TD_Plot');

-- ============================================================================
-- MONITORING STAGE 10: Alert Thresholds
-- ============================================================================

-- Check for performance degradation or issues
SELECT
    'Performance Alerts' as alert_category,
    CASE
        WHEN (SELECT MAX(duration_seconds)
              FROM {USER_DATABASE}.uaf_performance_log
              WHERE function_name = 'TD_Plot'
                AND start_timestamp >= CURRENT_TIMESTAMP - INTERVAL '7' DAY) >
             2 * (SELECT AVG(duration_seconds)
                  FROM {USER_DATABASE}.uaf_performance_log
                  WHERE function_name = 'TD_Plot'
                    AND start_timestamp >= CURRENT_TIMESTAMP - INTERVAL '30' DAY)
        THEN 'WARNING: Recent execution significantly slower than average'
        ELSE 'OK: Performance within normal range'
    END as duration_alert,
    CASE
        WHEN (SELECT COUNT(*)
              FROM {USER_DATABASE}.uaf_performance_log
              WHERE function_name = 'TD_Plot'
                AND status = 'FAILED'
                AND start_timestamp >= CURRENT_TIMESTAMP - INTERVAL '7' DAY) > 0
        THEN 'WARNING: Recent execution failures detected'
        ELSE 'OK: No recent failures'
    END as failure_alert,
    CASE
        WHEN (SELECT SUM(CurrentPerm) / 1024 / 1024
              FROM DBC.TableSize
              WHERE DatabaseName = '{USER_DATABASE}'
                AND TableName LIKE '%plot%') > 5000
        THEN 'WARNING: Result tables consuming >5GB storage'
        ELSE 'OK: Storage usage acceptable'
    END as storage_alert;

-- ============================================================================
-- PERFORMANCE MONITORING SUMMARY
-- ============================================================================

SELECT
    'Performance Monitoring Complete' as status,
    CURRENT_TIMESTAMP as monitoring_timestamp,
    'Review alerts and optimization recommendations above' as action_required;

-- ============================================================================
-- PERFORMANCE MONITORING CHECKLIST:
-- ============================================================================
/*
□ Execution time tracked and logged
□ Resource usage analyzed (CPU, I/O, storage)
□ Data distribution and skew checked
□ Result quality metrics calculated
□ Storage optimization opportunities identified
□ Data quality issues detected
□ Performance benchmarks established
□ Health dashboard metrics updated
□ Alert thresholds evaluated
□ Performance log updated with results
*/
-- =====================================================
