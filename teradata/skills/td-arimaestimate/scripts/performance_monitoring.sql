-- =====================================================
-- TD_ARIMAESTIMATE - UAF Performance Monitoring
-- =====================================================
-- Purpose: Monitor and optimize TD_ARIMAESTIMATE execution
-- Function: TD_ARIMAESTIMATE performance tracking
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
CREATE MULTISET TABLE {USER_DATABASE}.uaf_performance_log (
    execution_id INTEGER,
    function_name VARCHAR(100),
    database_name VARCHAR(100),
    table_name VARCHAR(100),
    start_timestamp TIMESTAMP,
    end_timestamp TIMESTAMP,
    duration_seconds DECIMAL(12,2),
    n_observations INTEGER,
    n_parameters INTEGER,
    model_specification VARCHAR(200),
    aic_value DECIMAL(12,4),
    bic_value DECIMAL(12,4),
    status VARCHAR(50),
    error_message VARCHAR(1000)
) PRIMARY INDEX (execution_id);

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
    NEXT VALUE FOR {USER_DATABASE}.uaf_execution_seq,  -- Create sequence first
    'TD_ARIMAESTIMATE',
    '{USER_DATABASE}',
    'uaf_arimaestimate_input',
    CURRENT_TIMESTAMP,
    (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_arimaestimate_input),
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
  AND TableName IN ('uaf_arimaestimate_input', 'arimaestimate_results')
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
FROM {USER_DATABASE}.uaf_arimaestimate_input
GROUP BY HashAmp()
ORDER BY amp_number;

-- ============================================================================
-- MONITORING STAGE 3: Query Performance Statistics
-- ============================================================================

-- Monitor recent TD_ARIMAESTIMATE executions
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
WHERE QueryText LIKE '%TD_ARIMAESTIMATE%'
  AND LogDate >= CURRENT_DATE - 7
  AND UserName = USER
ORDER BY StartTime DESC;

-- ============================================================================
-- MONITORING STAGE 4: Model Complexity Metrics
-- ============================================================================

-- Analyze model complexity and estimation quality
SELECT
    'Model Complexity Analysis' as metric_category,
    (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_arimaestimate_input) as n_observations,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients') as n_parameters,
    CAST(
        (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients') /
        CAST((SELECT COUNT(*) FROM {USER_DATABASE}.uaf_arimaestimate_input) AS FLOAT) * 100
        AS DECIMAL(8,2)
    ) as parameter_to_obs_ratio_pct,
    CASE
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients') /
             CAST((SELECT COUNT(*) FROM {USER_DATABASE}.uaf_arimaestimate_input) AS FLOAT) < 0.05
        THEN 'Excellent - Low parameter ratio (<5%)'
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients') /
             CAST((SELECT COUNT(*) FROM {USER_DATABASE}.uaf_arimaestimate_input) AS FLOAT) < 0.10
        THEN 'Good - Acceptable parameter ratio (<10%)'
        ELSE 'Warning - High parameter ratio may indicate overfitting'
    END as complexity_assessment;

-- ============================================================================
-- MONITORING STAGE 5: Convergence and Estimation Quality
-- ============================================================================

-- Check estimation convergence and quality indicators
SELECT
    'Estimation Quality Metrics' as metric_category,
    (SELECT CAST(statistic_value AS DECIMAL(12,4))
     FROM {USER_DATABASE}.arimaestimate_results
     WHERE result_type = 'FitStatistics' AND statistic_name = 'LogLikelihood') as log_likelihood,
    (SELECT CAST(statistic_value AS DECIMAL(12,4))
     FROM {USER_DATABASE}.arimaestimate_results
     WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC') as AIC,
    (SELECT CAST(statistic_value AS DECIMAL(12,4))
     FROM {USER_DATABASE}.arimaestimate_results
     WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC') as BIC,
    (SELECT COUNT(*)
     FROM {USER_DATABASE}.arimaestimate_results
     WHERE result_type = 'Coefficients'
       AND ABS(coefficient_value / NULLIF(std_error, 0)) > 1.96) as n_significant_coefficients,
    (SELECT COUNT(*)
     FROM {USER_DATABASE}.arimaestimate_results
     WHERE result_type = 'Coefficients') as total_coefficients,
    CAST(
        (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results
         WHERE result_type = 'Coefficients' AND ABS(coefficient_value / NULLIF(std_error, 0)) > 1.96) /
        CAST((SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients') AS FLOAT) * 100
        AS DECIMAL(8,2)
    ) as pct_significant_params,
    CASE
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results
              WHERE result_type = 'Coefficients' AND ABS(coefficient_value / NULLIF(std_error, 0)) > 1.96) /
             CAST((SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients') AS FLOAT) > 0.8
        THEN 'Excellent - Most parameters are significant'
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results
              WHERE result_type = 'Coefficients' AND ABS(coefficient_value / NULLIF(std_error, 0)) > 1.96) /
             CAST((SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients') AS FLOAT) > 0.5
        THEN 'Good - Majority of parameters are significant'
        ELSE 'Warning - Many parameters are not significant'
    END as parameter_quality;

-- ============================================================================
-- MONITORING STAGE 6: Memory and Storage Optimization
-- ============================================================================

-- Analyze result table sizes
SELECT
    'Storage Analysis' as analysis_type,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients') as coefficient_rows,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Residuals') as residual_rows,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'FittedValues') as fitted_value_rows,
    (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'FitStatistics') as fit_stat_rows,
    (SELECT SUM(CurrentPerm) / 1024 / 1024
     FROM DBC.TableSize
     WHERE DatabaseName = '{USER_DATABASE}'
       AND TableName = 'arimaestimate_results') as total_size_mb;

-- Identify optimization opportunities
SELECT
    'Optimization Recommendations' as recommendation_type,
    CASE
        WHEN (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_arimaestimate_input) > 10000
        THEN 'Consider partitioning input table by time ranges for very large datasets'
        ELSE 'Current dataset size is optimal for single-table processing'
    END as data_partitioning,
    CASE
        WHEN (SELECT MAX(COUNT(*)) OVER () / NULLIF(AVG(COUNT(*)) OVER (), 0)
              FROM {USER_DATABASE}.uaf_arimaestimate_input
              GROUP BY HashAmp()) > 1.5
        THEN 'Review primary index to reduce data skew'
        ELSE 'Data distribution is acceptable'
    END as index_optimization,
    CASE
        WHEN (SELECT CurrentPerm / 1024 / 1024
              FROM DBC.TableSize
              WHERE DatabaseName = '{USER_DATABASE}' AND TableName = 'arimaestimate_results') > 1000
        THEN 'Consider archiving or summarizing historical results'
        ELSE 'Result table size is manageable'
    END as storage_management;

-- ============================================================================
-- MONITORING STAGE 7: Error Detection and Handling
-- ============================================================================

-- Check for potential data quality issues
SELECT
    'Data Quality Checks' as check_category,
    (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_arimaestimate_input WHERE series_value IS NULL) as null_values,
    (SELECT COUNT(*)
     FROM {USER_DATABASE}.uaf_arimaestimate_input
     WHERE ABS(series_value - (SELECT AVG(series_value) FROM {USER_DATABASE}.uaf_arimaestimate_input)) >
           3 * (SELECT STDDEV(series_value) FROM {USER_DATABASE}.uaf_arimaestimate_input)) as outliers_3sd,
    (SELECT COUNT(DISTINCT time_index) FROM {USER_DATABASE}.uaf_arimaestimate_input) as distinct_timestamps,
    (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_arimaestimate_input) as total_rows,
    CASE
        WHEN (SELECT COUNT(DISTINCT time_index) FROM {USER_DATABASE}.uaf_arimaestimate_input) =
             (SELECT COUNT(*) FROM {USER_DATABASE}.uaf_arimaestimate_input)
        THEN 'No duplicate timestamps'
        ELSE 'Warning: Duplicate timestamps detected'
    END as timestamp_uniqueness;

-- ============================================================================
-- MONITORING STAGE 8: Execution Benchmarking
-- ============================================================================

-- Compare execution times across different model specifications
SELECT
    model_specification,
    n_observations,
    n_parameters,
    duration_seconds,
    duration_seconds / n_observations as seconds_per_observation,
    aic_value,
    CASE
        WHEN duration_seconds < 10 THEN 'Fast (<10s)'
        WHEN duration_seconds < 60 THEN 'Moderate (<1min)'
        WHEN duration_seconds < 300 THEN 'Slow (<5min)'
        ELSE 'Very slow (>5min)'
    END as performance_category
FROM {USER_DATABASE}.uaf_performance_log
WHERE function_name = 'TD_ARIMAESTIMATE'
  AND status = 'COMPLETED'
ORDER BY start_timestamp DESC
LIMIT 20;

-- ============================================================================
-- MONITORING STAGE 9: Production Health Dashboard
-- ============================================================================

-- Overall UAF TD_ARIMAESTIMATE health metrics
SELECT
    'UAF Performance Dashboard' as dashboard_section,
    COUNT(*) as total_executions,
    SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) as successful_executions,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed_executions,
    CAST(AVG(CASE WHEN status = 'COMPLETED' THEN duration_seconds ELSE NULL END) AS DECIMAL(12,2)) as avg_duration_seconds,
    CAST(MIN(CASE WHEN status = 'COMPLETED' THEN duration_seconds ELSE NULL END) AS DECIMAL(12,2)) as min_duration_seconds,
    CAST(MAX(CASE WHEN status = 'COMPLETED' THEN duration_seconds ELSE NULL END) AS DECIMAL(12,2)) as max_duration_seconds,
    CAST(AVG(n_observations) AS INTEGER) as avg_observations,
    CAST(AVG(CASE WHEN status = 'COMPLETED' THEN aic_value ELSE NULL END) AS DECIMAL(12,4)) as avg_aic
FROM {USER_DATABASE}.uaf_performance_log
WHERE function_name = 'TD_ARIMAESTIMATE'
  AND start_timestamp >= CURRENT_TIMESTAMP - INTERVAL '30' DAY;

-- ============================================================================
-- MONITORING STAGE 10: Update Performance Log (Post-Execution)
-- ============================================================================

-- Update execution log with completion metrics
UPDATE {USER_DATABASE}.uaf_performance_log
SET
    end_timestamp = CURRENT_TIMESTAMP,
    duration_seconds = CAST((CURRENT_TIMESTAMP - start_timestamp) SECOND(4,2) AS DECIMAL(12,2)),
    n_parameters = (SELECT COUNT(*) FROM {USER_DATABASE}.arimaestimate_results WHERE result_type = 'Coefficients'),
    model_specification = 'ARIMA(p,d,q)',  -- Update with actual specification
    aic_value = (SELECT CAST(statistic_value AS DECIMAL(12,4))
                 FROM {USER_DATABASE}.arimaestimate_results
                 WHERE result_type = 'FitStatistics' AND statistic_name = 'AIC'),
    bic_value = (SELECT CAST(statistic_value AS DECIMAL(12,4))
                 FROM {USER_DATABASE}.arimaestimate_results
                 WHERE result_type = 'FitStatistics' AND statistic_name = 'BIC'),
    status = 'COMPLETED'
WHERE execution_id = (SELECT MAX(execution_id)
                      FROM {USER_DATABASE}.uaf_performance_log
                      WHERE function_name = 'TD_ARIMAESTIMATE');

-- ============================================================================
-- MONITORING STAGE 11: Alert Thresholds
-- ============================================================================

-- Check for performance degradation or issues
SELECT
    'Performance Alerts' as alert_category,
    CASE
        WHEN (SELECT MAX(duration_seconds)
              FROM {USER_DATABASE}.uaf_performance_log
              WHERE function_name = 'TD_ARIMAESTIMATE'
                AND start_timestamp >= CURRENT_TIMESTAMP - INTERVAL '7' DAY) >
             2 * (SELECT AVG(duration_seconds)
                  FROM {USER_DATABASE}.uaf_performance_log
                  WHERE function_name = 'TD_ARIMAESTIMATE'
                    AND start_timestamp >= CURRENT_TIMESTAMP - INTERVAL '30' DAY)
        THEN 'WARNING: Recent execution significantly slower than average'
        ELSE 'OK: Performance within normal range'
    END as duration_alert,
    CASE
        WHEN (SELECT COUNT(*)
              FROM {USER_DATABASE}.uaf_performance_log
              WHERE function_name = 'TD_ARIMAESTIMATE'
                AND status = 'FAILED'
                AND start_timestamp >= CURRENT_TIMESTAMP - INTERVAL '7' DAY) > 0
        THEN 'WARNING: Recent execution failures detected'
        ELSE 'OK: No recent failures'
    END as failure_alert,
    CASE
        WHEN (SELECT SUM(CurrentPerm) / 1024 / 1024
              FROM DBC.TableSize
              WHERE DatabaseName = '{USER_DATABASE}'
                AND TableName LIKE '%arima%') > 5000
        THEN 'WARNING: ARIMA result tables consuming >5GB storage'
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
□ Model complexity metrics calculated
□ Convergence quality verified
□ Storage optimization opportunities identified
□ Data quality issues detected
□ Performance benchmarks established
□ Health dashboard metrics updated
□ Alert thresholds evaluated
□ Performance log updated with results
*/
-- =====================================================
