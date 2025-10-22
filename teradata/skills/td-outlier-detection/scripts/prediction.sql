-- =====================================================
-- TD_OutlierDetection - Detect Outliers in New Data Script
-- =====================================================
-- Purpose: Apply fitted outlier detection to new data
-- Input: Fitted outlier detection parameters and new data
-- Output: Data with outlier flags and scores
-- Note: This is preprocessing/analysis, not prediction
-- =====================================================

-- Step 1: Verify outlier detection parameters exist
SELECT * FROM {model_database}.outlier_fit_out;

-- Step 2: Apply outlier detection to new data
DROP TABLE IF EXISTS {output_database}.outlier_detection_out;
CREATE MULTISET TABLE {output_database}.outlier_detection_out AS (
    SELECT * FROM TD_OutlierDetection (
        ON {test_data_database}.{test_data_table} AS InputTable
        ON {model_database}.outlier_fit_out AS FitTable DIMENSION
        USING
        TargetColumns ({target_columns})
        IDColumn ('{id_column}')
        Accumulate ('{id_column}', '{additional_columns}')
    ) as dt
) WITH DATA;

-- Step 3: View outlier detection results sample
SELECT TOP 100 * FROM {output_database}.outlier_detection_out
ORDER BY {id_column};

-- Step 4: Count outliers detected
SELECT
    is_outlier,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {output_database}.outlier_detection_out
GROUP BY is_outlier
ORDER BY is_outlier;

-- Step 5: Outlier statistics by feature
SELECT
    '{column_1}' as feature_name,
    COUNT(*) as total_rows,
    SUM(CASE WHEN is_outlier = 1 THEN 1 ELSE 0 END) as outlier_count,
    CAST(SUM(CASE WHEN is_outlier = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as outlier_percentage,
    AVG(outlier_score) as avg_outlier_score,
    MAX(outlier_score) as max_outlier_score
FROM {output_database}.outlier_detection_out;

-- Step 6: Top outliers by score
SELECT
    {id_column},
    is_outlier,
    outlier_score,
    {column_1},
    {column_2}
FROM {output_database}.outlier_detection_out
WHERE is_outlier = 1
ORDER BY outlier_score DESC
LIMIT 50;

-- Step 7: Compare outliers vs non-outliers statistics
SELECT
    is_outlier,
    COUNT(*) as count,
    AVG({column_1}) as avg_col1,
    STDDEV({column_1}) as std_col1,
    MIN({column_1}) as min_col1,
    MAX({column_1}) as max_col1,
    AVG({column_2}) as avg_col2,
    STDDEV({column_2}) as std_col2,
    MIN({column_2}) as min_col2,
    MAX({column_2}) as max_col2
FROM {output_database}.outlier_detection_out
GROUP BY is_outlier
ORDER BY is_outlier;

-- Step 8: Data integrity check - no rows lost
SELECT
    'Integrity Check' as check_type,
    (SELECT COUNT(*) FROM {test_data_database}.{test_data_table}) as original_rows,
    (SELECT COUNT(*) FROM {output_database}.outlier_detection_out) as processed_rows,
    CASE
        WHEN (SELECT COUNT(*) FROM {test_data_database}.{test_data_table}) =
             (SELECT COUNT(*) FROM {output_database}.outlier_detection_out)
        THEN 'PASS - No Data Loss'
        ELSE 'FAIL - Row Count Mismatch'
    END as integrity_status;

-- Step 9: Create clean dataset (outliers removed) - Optional
/*
DROP TABLE IF EXISTS {output_database}.clean_data_out;
CREATE MULTISET TABLE {output_database}.clean_data_out AS (
    SELECT
        o.*
    FROM {test_data_database}.{test_data_table} o
    JOIN {output_database}.outlier_detection_out d
        ON o.{id_column} = d.{id_column}
    WHERE d.is_outlier = 0
) WITH DATA;

SELECT 'Clean Dataset Created' as status,
       COUNT(*) as row_count
FROM {output_database}.clean_data_out;
*/

-- Step 10: Outlier score distribution
WITH score_bins AS (
    SELECT
        CASE
            WHEN outlier_score < 0.2 THEN '0.0-0.2 (Very Normal)'
            WHEN outlier_score < 0.4 THEN '0.2-0.4 (Normal)'
            WHEN outlier_score < 0.6 THEN '0.4-0.6 (Moderate)'
            WHEN outlier_score < 0.8 THEN '0.6-0.8 (Suspicious)'
            ELSE '0.8-1.0 (Strong Outlier)'
        END as score_range,
        COUNT(*) as count
    FROM {output_database}.outlier_detection_out
    GROUP BY score_range
)
SELECT
    score_range,
    count,
    CAST(count * 100.0 / SUM(count) OVER() AS DECIMAL(5,2)) as percentage
FROM score_bins
ORDER BY score_range;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {model_database} - Database containing fitted outlier detector
--    {test_data_database} - Database with new data
--    {test_data_table} - Table name for new data
--    {output_database} - Where to store detection results
--    {id_column} - Unique identifier column
--    {target_columns} - Columns to check for outliers
--    {additional_columns} - Columns to keep but not analyze
--    {column_1}, {column_2} - Specific columns for analysis
--
-- 2. Prerequisites:
--    - Fitted outlier detector (TD_OutlierFit output) must exist
--    - New data must have same features as training data
--    - Features must be numeric
--
-- 3. Detection methods:
--    - IQR: Interquartile range method (robust)
--    - Z-Score: Standard deviation method
--    - Isolation Forest: ML-based detection
--    - Local Outlier Factor: Density-based detection
--
-- 4. When to use:
--    - Data quality validation
--    - Fraud detection
--    - Anomaly detection in time series
--    - Before model training (to remove noise)
--    - NOT for valid extreme values (e.g., legitimate large transactions)
--
-- =====================================================
