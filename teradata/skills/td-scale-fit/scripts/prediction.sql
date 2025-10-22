-- =====================================================
-- TD_ScaleTransform - Transform New Data Script
-- =====================================================
-- Purpose: Apply fitted scaling transformation to new data
-- Input: Fitted scaler parameters and new data
-- Output: Scaled/normalized features
-- Note: This is preprocessing transformation, not prediction
-- =====================================================

-- Step 1: Verify scaling parameters exist
SELECT * FROM {model_database}.scale_fit_out;

-- Step 2: Apply scaling transformation to new data
DROP TABLE IF EXISTS {output_database}.scaled_data_out;
CREATE MULTISET TABLE {output_database}.scaled_data_out AS (
    SELECT * FROM TD_ScaleTransform (
        ON {test_data_database}.{test_data_table} AS InputTable
        ON {model_database}.scale_fit_out AS FitTable DIMENSION
        USING
        TargetColumns ({feature_columns})
        IDColumn ('{id_column}')
        Accumulate ('{id_column}', '{additional_columns}')
    ) as dt
) WITH DATA;

-- Step 3: View scaled data sample
SELECT TOP 100 * FROM {output_database}.scaled_data_out
ORDER BY {id_column};

-- Step 4: Verify scaling applied correctly
-- Compare original vs scaled data statistics
SELECT
    'Original Data' as data_type,
    '{feature_column_1}' as feature,
    MIN({feature_column_1}) as min_value,
    MAX({feature_column_1}) as max_value,
    AVG({feature_column_1}) as mean_value,
    STDDEV({feature_column_1}) as std_dev
FROM {test_data_database}.{test_data_table}

UNION ALL

SELECT
    'Scaled Data' as data_type,
    '{feature_column_1}_scaled' as feature,
    MIN({feature_column_1}_scaled) as min_value,
    MAX({feature_column_1}_scaled) as max_value,
    AVG({feature_column_1}_scaled) as mean_value,
    STDDEV({feature_column_1}_scaled) as std_dev
FROM {output_database}.scaled_data_out;

-- Step 5: Check for scaling method consistency
-- MinMax scaling should result in [0, 1] range
-- Z-score scaling should result in mean≈0, std≈1
SELECT
    '{feature_column_1}_scaled' as scaled_feature,
    MIN({feature_column_1}_scaled) as min_val,
    MAX({feature_column_1}_scaled) as max_val,
    AVG({feature_column_1}_scaled) as mean_val,
    STDDEV({feature_column_1}_scaled) as std_val,
    CASE
        WHEN MIN({feature_column_1}_scaled) >= 0 AND MAX({feature_column_1}_scaled) <= 1
        THEN 'Likely MinMax Scaling'
        WHEN ABS(AVG({feature_column_1}_scaled)) < 0.1 AND ABS(STDDEV({feature_column_1}_scaled) - 1) < 0.1
        THEN 'Likely Z-Score Scaling'
        ELSE 'Other Scaling Method'
    END as scaling_method_detected
FROM {output_database}.scaled_data_out;

-- Step 6: Data integrity check - no rows lost
SELECT
    'Integrity Check' as check_type,
    (SELECT COUNT(*) FROM {test_data_database}.{test_data_table}) as original_rows,
    (SELECT COUNT(*) FROM {output_database}.scaled_data_out) as scaled_rows,
    CASE
        WHEN (SELECT COUNT(*) FROM {test_data_database}.{test_data_table}) =
             (SELECT COUNT(*) FROM {output_database}.scaled_data_out)
        THEN 'PASS - No Data Loss'
        ELSE 'FAIL - Row Count Mismatch'
    END as integrity_status;

-- Step 7: Check for outliers after scaling
WITH scaled_stats AS (
    SELECT
        {feature_column_1}_scaled,
        AVG({feature_column_1}_scaled) OVER() as mean_val,
        STDDEV({feature_column_1}_scaled) OVER() as std_val
    FROM {output_database}.scaled_data_out
)
SELECT
    COUNT(*) as total_outliers,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {output_database}.scaled_data_out) AS DECIMAL(5,2)) as outlier_percentage
FROM scaled_stats
WHERE ABS({feature_column_1}_scaled - mean_val) > 3 * std_val;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {model_database} - Database containing fitted scaler
--    {test_data_database} - Database with new data
--    {test_data_table} - Table name for new data
--    {output_database} - Where to store scaled data
--    {id_column} - Unique identifier column
--    {feature_columns} - Columns to scale
--    {additional_columns} - Columns to keep but not scale
--
-- 2. Prerequisites:
--    - Fitted scaler (TD_ScaleFit output) must exist
--    - New data must have same features as training data
--    - Features must be numeric
--
-- 3. Scaling methods:
--    - MinMax: Scales to [0, 1] or [min, max] range
--    - Z-score (Standardization): Scales to mean=0, std=1
--    - MaxAbs: Scales to [-1, 1] preserving zero
--    - Robust: Uses median and IQR, robust to outliers
--
-- 4. When to use:
--    - Before distance-based algorithms (K-Means, KNN, SVM)
--    - Before gradient descent optimization
--    - When features have different scales/units
--    - NOT typically needed for tree-based models
--
-- =====================================================
