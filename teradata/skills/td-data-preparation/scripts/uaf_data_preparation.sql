-- UAF Data Preparation for TD_DATA_PREPARATION
-- Prepares time series data for UAF Model Preparation workflows
-- Focus: Data validation, time series formatting, missing value detection, quality checks

-- INSTRUCTIONS:
-- 1. Replace {USER_DATABASE} with your database name
-- 2. Replace {USER_TABLE} with your time series table name
-- 3. Replace {TIMESTAMP_COLUMN} with your time column
-- 4. Replace {VALUE_COLUMNS} with comma-separated value columns
-- 5. Replace {ID_COLUMN} with entity/series identifier column (optional)

-- ============================================================================
-- STEP 1: Data Validation and Quality Checks
-- ============================================================================

-- Check for missing timestamps
SELECT
    'Missing Timestamps' as ValidationCheck,
    COUNT(*) as TotalGaps,
    AVG(gap_hours) as AvgGapHours,
    MAX(gap_hours) as MaxGapHours
FROM (
    SELECT
        {TIMESTAMP_COLUMN},
        CAST((LEAD({TIMESTAMP_COLUMN}) OVER (ORDER BY {TIMESTAMP_COLUMN}) - {TIMESTAMP_COLUMN}) HOUR AS DECIMAL(10,2)) as gap_hours
    FROM {USER_DATABASE}.{USER_TABLE}
) gaps
WHERE gap_hours > 1.5;  -- Adjust threshold based on expected frequency

-- Check for duplicate timestamps
SELECT
    'Duplicate Timestamps' as ValidationCheck,
    {TIMESTAMP_COLUMN},
    COUNT(*) as DuplicateCount
FROM {USER_DATABASE}.{USER_TABLE}
GROUP BY {TIMESTAMP_COLUMN}
HAVING COUNT(*) > 1
ORDER BY DuplicateCount DESC;

-- Missing value detection
SELECT
    'Missing Values Analysis' as ValidationCheck,
    COUNT(*) as TotalRows,
    COUNT({VALUE_COLUMNS}) as NonNullRows,
    COUNT(*) - COUNT({VALUE_COLUMNS}) as NullCount,
    CAST(100.0 * (COUNT(*) - COUNT({VALUE_COLUMNS})) / COUNT(*) AS DECIMAL(5,2)) as MissingPct
FROM {USER_DATABASE}.{USER_TABLE};

-- ============================================================================
-- STEP 2: Time Series Formatting and Standardization
-- ============================================================================

-- Create properly formatted time series table
DROP TABLE IF EXISTS uaf_formatted_timeseries;
CREATE MULTISET TABLE uaf_formatted_timeseries AS (
    SELECT
        {TIMESTAMP_COLUMN} as ts,
        {VALUE_COLUMNS} as value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as time_index,
        -- Calculate time-based features
        EXTRACT(YEAR FROM {TIMESTAMP_COLUMN}) as year,
        EXTRACT(MONTH FROM {TIMESTAMP_COLUMN}) as month,
        EXTRACT(DAY FROM {TIMESTAMP_COLUMN}) as day,
        EXTRACT(HOUR FROM {TIMESTAMP_COLUMN}) as hour,
        -- Flag weekend vs weekday
        CASE WHEN EXTRACT(DOW FROM {TIMESTAMP_COLUMN}) IN (0, 6)
             THEN 1 ELSE 0 END as is_weekend
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {TIMESTAMP_COLUMN} IS NOT NULL
) WITH DATA;

-- ============================================================================
-- STEP 3: Missing Data Handling
-- ============================================================================

-- Option 1: Forward fill missing values
DROP TABLE IF EXISTS uaf_filled_timeseries;
CREATE MULTISET TABLE uaf_filled_timeseries AS (
    SELECT
        ts,
        COALESCE(value, LAST_VALUE(value IGNORE NULLS) OVER (ORDER BY ts ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)) as value_filled,
        CASE WHEN value IS NULL THEN 1 ELSE 0 END as was_imputed,
        time_index
    FROM uaf_formatted_timeseries
) WITH DATA;

-- Option 2: Linear interpolation for missing values
DROP TABLE IF EXISTS uaf_interpolated_timeseries;
CREATE MULTISET TABLE uaf_interpolated_timeseries AS (
    SELECT
        ts,
        CASE
            WHEN value IS NOT NULL THEN value
            WHEN prev_value IS NOT NULL AND next_value IS NOT NULL THEN
                prev_value + (next_value - prev_value) *
                (ts - prev_ts) / (next_ts - prev_ts)
            ELSE COALESCE(prev_value, next_value)
        END as value_interpolated,
        time_index
    FROM (
        SELECT
            ts,
            value,
            time_index,
            LAST_VALUE(value IGNORE NULLS) OVER (ORDER BY ts ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as prev_value,
            LAST_VALUE(ts IGNORE NULLS) OVER (ORDER BY ts ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as prev_ts,
            FIRST_VALUE(value IGNORE NULLS) OVER (ORDER BY ts ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) as next_value,
            FIRST_VALUE(ts IGNORE NULLS) OVER (ORDER BY ts ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) as next_ts
        FROM uaf_formatted_timeseries
    ) t
) WITH DATA;

-- ============================================================================
-- STEP 4: Data Quality Assessment
-- ============================================================================

-- Statistical outlier detection
SELECT
    'Outlier Detection' as QualityCheck,
    COUNT(*) as TotalOutliers,
    MIN(value) as MinOutlier,
    MAX(value) as MaxOutlier
FROM (
    SELECT
        ts,
        value,
        AVG(value) OVER () as mean_value,
        STDDEV(value) OVER () as stddev_value
    FROM uaf_formatted_timeseries
    WHERE value IS NOT NULL
) stats
WHERE ABS(value - mean_value) > 3 * stddev_value;

-- Consistency check across time
SELECT
    'Temporal Consistency' as QualityCheck,
    COUNT(*) as TotalRows,
    MIN(ts) as MinTimestamp,
    MAX(ts) as MaxTimestamp,
    CAST((MAX(ts) - MIN(ts)) DAY AS INTEGER) as TotalDays,
    COUNT(DISTINCT ts) as UniqueTimestamps,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT ts) THEN 'No Duplicates'
        ELSE 'Duplicates Found'
    END as DuplicateStatus
FROM uaf_formatted_timeseries;

-- ============================================================================
-- STEP 5: UAF-Ready Dataset Preparation
-- ============================================================================

-- Final UAF-optimized table
DROP TABLE IF EXISTS uaf_ready_data;
CREATE MULTISET TABLE uaf_ready_data AS (
    SELECT
        time_index,
        ts as timestamp_col,
        value_interpolated as prepared_value,
        -- Add validation flags
        CASE WHEN value_interpolated IS NULL THEN 1 ELSE 0 END as has_null,
        CASE WHEN ABS(value_interpolated - avg_val) > 3 * stddev_val THEN 1 ELSE 0 END as is_outlier
    FROM uaf_interpolated_timeseries
    CROSS JOIN (
        SELECT
            AVG(value_interpolated) as avg_val,
            STDDEV(value_interpolated) as stddev_val
        FROM uaf_interpolated_timeseries
    ) stats
    ORDER BY time_index
) WITH DATA;

-- Data quality summary
SELECT
    'UAF Data Preparation Summary' as ReportType,
    COUNT(*) as TotalRows,
    SUM(has_null) as RemainingNulls,
    SUM(is_outlier) as DetectedOutliers,
    CAST(100.0 * SUM(is_outlier) / COUNT(*) AS DECIMAL(5,2)) as OutlierPct,
    MIN(timestamp_col) as StartDate,
    MAX(timestamp_col) as EndDate
FROM uaf_ready_data;

-- ============================================================================
-- STEP 6: Export for TD_DATA_PREPARATION
-- ============================================================================

-- Final dataset ready for UAF processing
SELECT * FROM uaf_ready_data
ORDER BY time_index;

/*
DATA PREPARATION CHECKLIST:
□ Validate temporal consistency and regular intervals
□ Handle missing values appropriately (forward fill or interpolation)
□ Detect and flag outliers for review
□ Ensure no duplicate timestamps
□ Verify data types are compatible with UAF functions
□ Document imputation and transformation methods
□ Test with subset before full processing
□ Monitor data quality metrics before UAF execution
□ Consider seasonal patterns in missing data handling
□ Validate statistical properties of prepared data

NEXT STEPS:
1. Review data quality summary
2. Adjust outlier thresholds if needed
3. Choose appropriate missing data strategy
4. Proceed to td_data_preparation_workflow.sql for UAF execution
5. Use parameter_optimization.sql to tune function parameters
*/
