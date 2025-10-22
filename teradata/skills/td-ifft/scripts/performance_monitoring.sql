-- TD_IFFT Performance Monitoring Script
-- Monitor UAF execution and resource utilization
-- Teradata Unbounded Array Framework implementation

-- Section 1: Query Execution Statistics
SELECT
    QueryID,
    UserName,
    StartTime,
    CURRENT_TIMESTAMP - StartTime as ElapsedTime,
    NumResultRows,
    TotalFirstRespTime,
    MaxAmpCPUTime
FROM DBC.QryLogV
WHERE QueryText LIKE '%TD_IFFT%'
AND QueryText NOT LIKE '%DBC.QryLogV%'
AND StartTime >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
ORDER BY StartTime DESC;

-- Section 2: Resource Utilization
DROP TABLE IF EXISTS _performance_metrics;
CREATE MULTISET TABLE _performance_metrics AS (
    SELECT
        QueryID,
        UserName,
        CAST(StartTime AS TIMESTAMP) as ExecutionStart,
        TotalFirstRespTime as ExecutionTime_Sec,
        NumResultRows,
        MaxAmpCPUTime,
        TotalIOCount,
        ReqPhysIOKB / 1024 as PhysicalIO_MB,
        CASE
            WHEN TotalFirstRespTime < 5 THEN 'Excellent'
            WHEN TotalFirstRespTime < 30 THEN 'Good'
            WHEN TotalFirstRespTime < 300 THEN 'Acceptable'
            ELSE 'Slow'
        END as PerformanceCategory
    FROM DBC.QryLogV
    WHERE QueryText LIKE '%TD_IFFT%'
    AND QueryText NOT LIKE '%DBC.QryLogV%'
    AND StartTime >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
) WITH DATA;

SELECT * FROM _performance_metrics
ORDER BY ExecutionStart DESC;

-- Section 3: Performance Summary
SELECT
    'Performance Summary' as ReportType,
    COUNT(*) as TotalExecutions,
    AVG(ExecutionTime_Sec) as AvgExecutionTime,
    MIN(ExecutionTime_Sec) as BestTime,
    MAX(ExecutionTime_Sec) as WorstTime,
    AVG(PhysicalIO_MB) as AvgIO_MB
FROM _performance_metrics;

/*
PERFORMANCE MONITORING CHECKLIST:
□ Execution times within acceptable range
□ Resource utilization optimized
□ No data skew detected
□ Consistent performance
□ Throughput meets requirements
*/
