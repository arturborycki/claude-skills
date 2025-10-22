-- TD_WINDOW Result Interpretation and Analysis Script
-- Comprehensive analysis and business interpretation
-- Teradata Unbounded Array Framework implementation

-- PREREQUISITES:
-- TD_WINDOW has been executed successfully
-- Results stored in td_window_results table

-- Section 1: Output Validation
SELECT
    'Output Validation' as CheckType,
    COUNT(*) as TotalRows,
    COUNT(DISTINCT time_index) as UniqueTimePoints,
    MIN(time_index) as StartTime,
    MAX(time_index) as EndTime,
    CURRENT_TIMESTAMP as ValidationTime
FROM td_window_results;

-- Section 2: Statistical Summary
DROP TABLE IF EXISTS td_window_statistics;
CREATE MULTISET TABLE td_window_statistics AS (
    SELECT
        'Statistical Summary' as MetricType,
        COUNT(*) as SampleCount,
        AVG(result_value) as Mean,
        STDDEV(result_value) as StdDev,
        MIN(result_value) as MinValue,
        MAX(result_value) as MaxValue,
        MAX(result_value) - MIN(result_value) as Range,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY result_value) as Median
    FROM td_window_results
) WITH DATA;

SELECT * FROM td_window_statistics;

-- Section 3: Quality Assessment
SELECT
    'Quality Metrics' as AssessmentType,
    CASE
        WHEN StdDev < Mean * 0.1 THEN 'Low variability - Stable signal'
        WHEN StdDev < Mean * 0.5 THEN 'Moderate variability'
        ELSE 'High variability - Check for issues'
    END as VariabilityAssessment,
    CASE
        WHEN (MaxValue - MinValue) / NULLIFZERO(Mean) < 2 THEN 'Narrow range'
        WHEN (MaxValue - MinValue) / NULLIFZERO(Mean) < 10 THEN 'Normal range'
        ELSE 'Wide range - Possible outliers'
    END as RangeAssessment
FROM td_window_statistics;

-- Section 4: Business Interpretation
SELECT '===== TD_WINDOW ANALYSIS SUMMARY =====' as Section
UNION ALL SELECT 'Total Samples: ' || CAST(SampleCount AS VARCHAR(20)) FROM td_window_statistics
UNION ALL SELECT 'Mean Value: ' || CAST(ROUND(Mean, 4) AS VARCHAR(20)) FROM td_window_statistics
UNION ALL SELECT 'Std Deviation: ' || CAST(ROUND(StdDev, 4) AS VARCHAR(20)) FROM td_window_statistics
UNION ALL SELECT 'Value Range: ' || CAST(ROUND(Range, 4) AS VARCHAR(20)) FROM td_window_statistics;

-- Section 5: Visualization Data Export
SELECT
    time_index,
    result_value,
    sample_id,
    CURRENT_TIMESTAMP as export_timestamp
FROM td_window_results
ORDER BY time_index;

/*
RESULT INTERPRETATION GUIDE:
- Review statistical measures for data quality
- Check for outliers and anomalies
- Validate results against expected patterns
- Export data for visualization
- Document findings for stakeholders

BUSINESS APPLICATIONS:
□ Signal quality assessment
□ Pattern identification
□ Anomaly detection
□ Trend analysis
□ Predictive insights
*/
