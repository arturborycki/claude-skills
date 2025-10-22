-- =====================================================
-- TD_ARIMAESTIMATE - UAF Data Preparation
-- =====================================================
-- Purpose: Prepare time series data for UAF ARIMA parameter estimation
-- Function: TD_ARIMAESTIMATE
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
DROP TABLE IF EXISTS {USER_DATABASE}.uaf_arimaestimate_input;
CREATE MULTISET TABLE {USER_DATABASE}.uaf_arimaestimate_input AS (
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
FROM {USER_DATABASE}.uaf_arimaestimate_input;

-- ============================================================================
-- STEP 5: Stationarity Assessment (Pre-ARIMA Check)
-- ============================================================================

-- Check for stationarity using rolling statistics
WITH rolling_stats AS (
    SELECT
        time_index,
        series_value,
        AVG(series_value) OVER (ORDER BY sequence_id ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) as rolling_mean_12,
        STDDEV(series_value) OVER (ORDER BY sequence_id ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) as rolling_std_12,
        AVG(series_value) OVER (ORDER BY sequence_id ROWS BETWEEN 23 PRECEDING AND CURRENT ROW) as rolling_mean_24,
        STDDEV(series_value) OVER (ORDER BY sequence_id ROWS BETWEEN 23 PRECEDING AND CURRENT ROW) as rolling_std_24
    FROM {USER_DATABASE}.uaf_arimaestimate_input
)
SELECT
    'Stationarity Assessment' as check_type,
    STDDEV(rolling_mean_12) as mean_variability_12period,
    STDDEV(rolling_std_12) as std_variability_12period,
    STDDEV(rolling_mean_24) as mean_variability_24period,
    STDDEV(rolling_std_24) as std_variability_24period,
    CASE
        WHEN STDDEV(rolling_mean_12) / NULLIF(AVG(rolling_mean_12), 0) < 0.1 THEN 'Likely stationary - d=0 may be sufficient'
        WHEN STDDEV(rolling_mean_12) / NULLIF(AVG(rolling_mean_12), 0) < 0.3 THEN 'Moderately non-stationary - d=1 recommended'
        ELSE 'Non-stationary - d=1 or d=2 required'
    END as stationarity_recommendation
FROM rolling_stats
WHERE rolling_mean_12 IS NOT NULL;

-- ============================================================================
-- STEP 6: Seasonal Pattern Detection
-- ============================================================================

-- Detect potential seasonal patterns
WITH lag_correlations AS (
    SELECT
        series_value,
        LAG(series_value, 7) OVER (ORDER BY sequence_id) as lag_7,
        LAG(series_value, 12) OVER (ORDER BY sequence_id) as lag_12,
        LAG(series_value, 24) OVER (ORDER BY sequence_id) as lag_24,
        LAG(series_value, 30) OVER (ORDER BY sequence_id) as lag_30
    FROM {USER_DATABASE}.uaf_arimaestimate_input
)
SELECT
    'Seasonal Pattern Detection' as analysis_type,
    CAST(CORR(series_value, lag_7) AS DECIMAL(8,4)) as correlation_lag7,
    CAST(CORR(series_value, lag_12) AS DECIMAL(8,4)) as correlation_lag12,
    CAST(CORR(series_value, lag_24) AS DECIMAL(8,4)) as correlation_lag24,
    CAST(CORR(series_value, lag_30) AS DECIMAL(8,4)) as correlation_lag30,
    CASE
        WHEN ABS(CORR(series_value, lag_7)) > 0.5 THEN 'Weekly seasonality detected (period=7)'
        WHEN ABS(CORR(series_value, lag_12)) > 0.5 THEN 'Monthly seasonality detected (period=12)'
        WHEN ABS(CORR(series_value, lag_24)) > 0.5 THEN 'Bi-annual seasonality detected (period=24)'
        WHEN ABS(CORR(series_value, lag_30)) > 0.5 THEN 'Monthly seasonality detected (period=30)'
        ELSE 'No strong seasonal pattern detected'
    END as seasonal_assessment
FROM lag_correlations;

-- ============================================================================
-- STEP 7: Missing Values and Outlier Detection
-- ============================================================================

-- Check for missing values and outliers
WITH value_stats AS (
    SELECT
        AVG(series_value) as mean_val,
        STDDEV(series_value) as std_val
    FROM {USER_DATABASE}.uaf_arimaestimate_input
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
FROM {USER_DATABASE}.uaf_arimaestimate_input;

-- ============================================================================
-- STEP 8: UAF Data Readiness Check
-- ============================================================================

-- Final data readiness assessment
SELECT
    'UAF TD_ARIMAESTIMATE Readiness' as status_type,
    COUNT(*) as n_observations,
    CASE
        WHEN COUNT(*) >= 100 THEN 'EXCELLENT - Sufficient data for robust estimation'
        WHEN COUNT(*) >= 50 THEN 'GOOD - Adequate data for parameter estimation'
        WHEN COUNT(*) >= 30 THEN 'ACCEPTABLE - Minimum data available'
        ELSE 'WARNING - Short time series may affect estimation quality'
    END as data_sufficiency,
    CASE
        WHEN COUNT(*) >= 50 THEN 'READY FOR TD_ARIMAESTIMATE'
        ELSE 'PROCEED WITH CAUTION'
    END as readiness
FROM {USER_DATABASE}.uaf_arimaestimate_input;

-- ============================================================================
-- UAF DATA PREPARATION CHECKLIST:
-- ============================================================================
/*
□ Time series structure validated
□ Gaps and frequency analyzed
□ UAF input table created with proper indexing
□ Stationarity assessed (d parameter guidance)
□ Seasonal patterns detected (seasonal parameters)
□ Missing values identified and handled
□ Outliers detected and reviewed
□ Data sufficiency confirmed (>=50 observations recommended)
□ Ready to proceed to parameter_optimization.sql
*/
-- =====================================================
