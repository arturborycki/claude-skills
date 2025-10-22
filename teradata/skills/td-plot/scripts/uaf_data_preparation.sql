-- =====================================================
-- TD_Plot - UAF Data Preparation
-- =====================================================
-- Purpose: Prepare time series data for UAF time series visualization
-- Function: TD_Plot
-- Framework: Teradata Unbounded Array Framework (UAF)
-- =====================================================

-- INSTRUCTIONS:
-- Replace {USER_DATABASE}, {USER_TABLE}, {TIMESTAMP_COLUMN}, {VALUE_COLUMNS}
-- with your actual database objects and column names

-- ============================================================================
-- STEP 1: Validate Time Series Structure
-- ============================================================================

-- Check time series data structure
SELECT TOP 20
    {TIMESTAMP_COLUMN} as time_index,
    {VALUE_COLUMNS} as series_value
FROM {USER_DATABASE}.{USER_TABLE}
ORDER BY {TIMESTAMP_COLUMN};

-- ============================================================================
-- STEP 2: Gap Detection and Frequency Analysis
-- ============================================================================

-- Check for gaps in time series
WITH time_diffs AS (
    SELECT
        {TIMESTAMP_COLUMN} as current_time,
        {VALUE_COLUMNS} as value,
        LAG({TIMESTAMP_COLUMN}) OVER (ORDER BY {TIMESTAMP_COLUMN}) as prev_time,
        {TIMESTAMP_COLUMN} - LAG({TIMESTAMP_COLUMN}) OVER (ORDER BY {TIMESTAMP_COLUMN}) as time_diff
    FROM {USER_DATABASE}.{USER_TABLE}
)
SELECT
    COUNT(*) as total_periods,
    COUNT(DISTINCT time_diff) as distinct_intervals,
    MIN(time_diff) as min_interval,
    MAX(time_diff) as max_interval,
    AVG(time_diff) as avg_interval,
    CASE
        WHEN COUNT(DISTINCT time_diff) = 1 THEN 'Regular intervals - OPTIMAL FOR UAF'
        WHEN COUNT(DISTINCT time_diff) <= 3 THEN 'Nearly regular - acceptable'
        ELSE 'Irregular intervals - preprocessing recommended'
    END as regularity_status
FROM time_diffs
WHERE time_diff IS NOT NULL;

-- ============================================================================
-- STEP 3: Create UAF-Optimized Time Series Table
-- ============================================================================

-- Create clean UAF input table with proper indexing
DROP TABLE IF EXISTS {USER_DATABASE}.uaf_plot_input;
CREATE MULTISET TABLE {USER_DATABASE}.uaf_plot_input AS (
    SELECT
        {TIMESTAMP_COLUMN} as time_index,
        CAST({VALUE_COLUMNS} AS FLOAT) as series_value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as sequence_id
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {VALUE_COLUMNS} IS NOT NULL
      AND {TIMESTAMP_COLUMN} IS NOT NULL
    ORDER BY {TIMESTAMP_COLUMN}
) WITH DATA
PRIMARY INDEX (sequence_id);

-- ============================================================================
-- STEP 4: Time Series Statistics and Quality Checks
-- ============================================================================

-- Basic time series statistics
SELECT
    'Time Series Summary' as metric_type,
    COUNT(*) as n_observations,
    MIN(time_index) as start_time,
    MAX(time_index) as end_time,
    MIN(series_value) as min_value,
    MAX(series_value) as max_value,
    AVG(series_value) as mean_value,
    STDDEV(series_value) as std_dev,
    STDDEV(series_value) / NULLIF(AVG(series_value), 0) as coefficient_of_variation
FROM {USER_DATABASE}.uaf_plot_input;

-- ============================================================================
-- STEP 5: Missing Values and Outlier Detection
-- ============================================================================

-- Check for missing values and outliers
WITH value_stats AS (
    SELECT
        AVG(series_value) as mean_val,
        STDDEV(series_value) as std_val
    FROM {USER_DATABASE}.uaf_plot_input
)
SELECT
    'Data Quality Check' as check_type,
    COUNT(*) as total_observations,
    SUM(CASE WHEN series_value IS NULL THEN 1 ELSE 0 END) as null_count,
    SUM(CASE
        WHEN ABS(series_value - (SELECT mean_val FROM value_stats)) > 3 * (SELECT std_val FROM value_stats)
        THEN 1 ELSE 0
    END) as potential_outliers,
    CASE
        WHEN SUM(CASE WHEN series_value IS NULL THEN 1 ELSE 0 END) = 0 THEN 'Clean data - ready for UAF'
        ELSE 'Warning - contains missing values'
    END as data_quality_status
FROM {USER_DATABASE}.uaf_plot_input;

-- ============================================================================
-- STEP 6: UAF Data Readiness Check
-- ============================================================================

-- Final data readiness assessment
SELECT
    'UAF TD_Plot Readiness' as status_type,
    COUNT(*) as n_observations,
    CASE
        WHEN COUNT(*) >= 100 THEN 'EXCELLENT - Sufficient data for robust analysis'
        WHEN COUNT(*) >= 50 THEN 'GOOD - Adequate data for analysis'
        WHEN COUNT(*) >= 30 THEN 'ACCEPTABLE - Minimum data available'
        ELSE 'WARNING - Short time series may affect analysis quality'
    END as data_sufficiency,
    CASE
        WHEN COUNT(*) >= 30 THEN 'READY FOR TD_Plot'
        ELSE 'PROCEED WITH CAUTION'
    END as readiness
FROM {USER_DATABASE}.uaf_plot_input;

-- ============================================================================
-- UAF DATA PREPARATION CHECKLIST:
-- ============================================================================
/*
□ Time series structure validated
□ Gaps and frequency analyzed
□ UAF input table created with proper indexing
□ Time series statistics calculated
□ Missing values identified and handled
□ Outliers detected and reviewed
□ Data sufficiency confirmed
□ Ready to proceed to workflow execution
*/
-- =====================================================
