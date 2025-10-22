-- Performance Monitoring for TD_DATA_PREPARATION
-- Track execution performance, data quality, and system resource utilization

-- ============================================================================
-- MONITORING OVERVIEW
-- ============================================================================
/*
Key Performance Indicators (KPIs):
1. Execution Time: Function runtime and throughput
2. Data Quality: Completeness, accuracy, consistency
3. Resource Utilization: CPU, memory, I/O
4. Error Rates: Failed executions and data issues
5. Trends: Performance degradation over time
*/

-- ============================================================================
-- 1. EXECUTION PERFORMANCE METRICS
-- ============================================================================

-- Create performance monitoring table
DROP TABLE IF EXISTS uaf_data_prep_performance;
CREATE MULTISET TABLE uaf_data_prep_performance (
    execution_id VARCHAR(100),
    execution_timestamp TIMESTAMP,
    records_input INTEGER,
    records_output INTEGER,
    records_rejected INTEGER,
    execution_time_sec DECIMAL(10,2),
    rows_per_second DECIMAL(12,2),
    cpu_time_sec DECIMAL(10,2),
    io_operations INTEGER,
    memory_mb DECIMAL(10,2),
    success_flag INTEGER,
    error_message VARCHAR(5000)
);

-- Log execution metrics (example)
INSERT INTO uaf_data_prep_performance VALUES (
    'EXEC_' || CAST(CURRENT_TIMESTAMP(0) AS VARCHAR(50)),
    CURRENT_TIMESTAMP,
    (SELECT COUNT(*) FROM uaf_raw_signal),
    (SELECT COUNT(*) FROM uaf_ready_data),
    (SELECT SUM(has_null) FROM uaf_ready_data),
    10.5,  -- Execution time
    (SELECT COUNT(*) FROM uaf_ready_data) / 10.5,
    8.2,   -- CPU time
    1500,  -- I/O ops
    512.0, -- Memory MB
    1,     -- Success
    NULL
);

-- Performance summary
SELECT
    'Execution Performance Summary' as MetricType,
    COUNT(*) as TotalExecutions,
    AVG(execution_time_sec) as AvgExecutionTimeSec,
    MIN(execution_time_sec) as MinExecutionTimeSec,
    MAX(execution_time_sec) as MaxExecutionTimeSec,
    AVG(rows_per_second) as AvgThroughput,
    SUM(records_input) as TotalRecordsProcessed,
    SUM(CASE WHEN success_flag = 1 THEN 1 ELSE 0 END) as SuccessfulExecutions,
    SUM(CASE WHEN success_flag = 0 THEN 1 ELSE 0 END) as FailedExecutions,
    CAST(SUM(CASE WHEN success_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as SuccessRate
FROM uaf_data_prep_performance;

-- ============================================================================
-- 2. DATA QUALITY METRICS
-- ============================================================================

DROP TABLE IF EXISTS uaf_data_quality_metrics;
CREATE MULTISET TABLE uaf_data_quality_metrics (
    metric_timestamp TIMESTAMP,
    metric_name VARCHAR(100),
    metric_value DECIMAL(18,6),
    threshold_value DECIMAL(18,6),
    status VARCHAR(20),
    alert_flag INTEGER
);

-- Calculate and log quality metrics
INSERT INTO uaf_data_quality_metrics
SELECT
    CURRENT_TIMESTAMP,
    'Completeness_Rate',
    CAST(100.0 * (COUNT(*) - SUM(has_null)) / COUNT(*) AS DECIMAL(18,6)),
    95.0,  -- Threshold
    CASE WHEN CAST(100.0 * (COUNT(*) - SUM(has_null)) / COUNT(*) AS DECIMAL(18,6)) >= 95.0
         THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN CAST(100.0 * (COUNT(*) - SUM(has_null)) / COUNT(*) AS DECIMAL(18,6)) < 95.0
         THEN 1 ELSE 0 END
FROM uaf_ready_data

UNION ALL

SELECT
    CURRENT_TIMESTAMP,
    'Outlier_Rate',
    CAST(100.0 * SUM(is_outlier) / COUNT(*) AS DECIMAL(18,6)),
    5.0,  -- Threshold
    CASE WHEN CAST(100.0 * SUM(is_outlier) / COUNT(*) AS DECIMAL(18,6)) <= 5.0
         THEN 'PASS' ELSE 'WARN' END,
    CASE WHEN CAST(100.0 * SUM(is_outlier) / COUNT(*) AS DECIMAL(18,6)) > 5.0
         THEN 1 ELSE 0 END
FROM uaf_ready_data;

-- Quality metrics dashboard
SELECT
    'Data Quality Dashboard' as ReportType,
    metric_name,
    CAST(metric_value AS DECIMAL(10,4)) as CurrentValue,
    CAST(threshold_value AS DECIMAL(10,4)) as Threshold,
    status,
    CASE WHEN alert_flag = 1 THEN 'ALERT' ELSE 'OK' END as AlertStatus
FROM uaf_data_quality_metrics
ORDER BY metric_timestamp DESC, metric_name;

-- ============================================================================
-- 3. RESOURCE UTILIZATION MONITORING
-- ============================================================================

SELECT
    'Resource Utilization' as MetricType,
    AVG(cpu_time_sec) as AvgCPU_Sec,
    AVG(memory_mb) as AvgMemory_MB,
    AVG(io_operations) as AvgIO_Operations,
    MAX(memory_mb) as PeakMemory_MB,
    AVG(cpu_time_sec / NULLIFZERO(execution_time_sec)) as CPUUtilizationRatio
FROM uaf_data_prep_performance
WHERE success_flag = 1;

-- ============================================================================
-- 4. TREND ANALYSIS
-- ============================================================================

-- Performance degradation detection
SELECT
    'Performance Trend Analysis' as AnalysisType,
    CAST(execution_timestamp AS DATE) as ExecutionDate,
    COUNT(*) as ExecutionCount,
    AVG(execution_time_sec) as AvgExecutionTime,
    AVG(rows_per_second) as AvgThroughput,
    -- 7-day moving average
    AVG(execution_time_sec) OVER (
        ORDER BY CAST(execution_timestamp AS DATE)
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as MA7_ExecutionTime
FROM uaf_data_prep_performance
GROUP BY CAST(execution_timestamp AS DATE)
ORDER BY CAST(execution_timestamp AS DATE) DESC;

-- ============================================================================
-- 5. ERROR MONITORING
-- ============================================================================

SELECT
    'Error Analysis' as ReportType,
    error_message,
    COUNT(*) as ErrorCount,
    MIN(execution_timestamp) as FirstOccurrence,
    MAX(execution_timestamp) as LastOccurrence,
    AVG(records_input) as AvgRecordsWhenError
FROM uaf_data_prep_performance
WHERE success_flag = 0
GROUP BY error_message
ORDER BY ErrorCount DESC;

-- ============================================================================
-- 6. ALERTING RULES
-- ============================================================================

-- Define alert conditions
SELECT
    'Active Alerts' as AlertType,
    CASE
        WHEN AVG(execution_time_sec) OVER (ORDER BY execution_timestamp ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) >
             AVG(execution_time_sec) * 1.5
        THEN 'Performance Degradation Detected'
        WHEN success_flag = 0
        THEN 'Execution Failure: ' || COALESCE(error_message, 'Unknown Error')
        WHEN records_rejected * 100.0 / NULLIFZERO(records_input) > 5.0
        THEN 'High Rejection Rate: ' || CAST(records_rejected * 100.0 / records_input AS DECIMAL(5,2)) || '%'
        ELSE 'No Alerts'
    END as AlertMessage,
    execution_timestamp,
    execution_id
FROM uaf_data_prep_performance
WHERE execution_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
ORDER BY execution_timestamp DESC;

/*
PERFORMANCE MONITORING CHECKLIST:
□ Track execution time and throughput
□ Monitor data quality metrics (completeness, accuracy)
□ Track resource utilization (CPU, memory, I/O)
□ Detect performance degradation trends
□ Log and analyze errors
□ Set up automated alerting
□ Review metrics daily/weekly
□ Investigate anomalies promptly

RECOMMENDED THRESHOLDS:
- Execution Time: Alert if > 2x baseline
- Completeness Rate: Alert if < 95%
- Outlier Rate: Warn if > 5%
- Success Rate: Alert if < 98%
- Throughput: Alert if < 50% of baseline

NEXT STEPS:
- Set up automated monitoring dashboard
- Configure alerting thresholds
- Integrate with monitoring tools (e.g., Grafana)
- Schedule regular performance reviews
- Establish escalation procedures
*/
