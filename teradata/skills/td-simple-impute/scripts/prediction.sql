-- =====================================================
-- TD_SimpleImputeTransform - Transform New Data Script
-- =====================================================
-- Purpose: Apply fitted imputation to new data with missing values
-- Input: Fitted imputation parameters and new data
-- Output: Data with imputed missing values
-- Note: This is preprocessing transformation, not prediction
-- =====================================================

-- Step 1: Verify imputation parameters exist
SELECT * FROM {model_database}.simple_impute_fit_out;

-- Step 2: Check missing values in new data before imputation
SELECT
    COUNT(*) as total_rows,
    COUNT({column_1}) as col1_non_null,
    COUNT(*) - COUNT({column_1}) as col1_null,
    CAST((COUNT(*) - COUNT({column_1})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as col1_null_pct,
    COUNT({column_2}) as col2_non_null,
    COUNT(*) - COUNT({column_2}) as col2_null,
    CAST((COUNT(*) - COUNT({column_2})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as col2_null_pct
FROM {test_data_database}.{test_data_table};

-- Step 3: Apply imputation transformation to new data
DROP TABLE IF EXISTS {output_database}.imputed_data_out;
CREATE MULTISET TABLE {output_database}.imputed_data_out AS (
    SELECT * FROM TD_SimpleImputeTransform (
        ON {test_data_database}.{test_data_table} AS InputTable
        ON {model_database}.simple_impute_fit_out AS FitTable DIMENSION
        USING
        TargetColumns ({target_columns})
        IDColumn ('{id_column}')
        Accumulate ('{id_column}', '{additional_columns}')
    ) as dt
) WITH DATA;

-- Step 4: View imputed data sample
SELECT TOP 100 * FROM {output_database}.imputed_data_out
ORDER BY {id_column};

-- Step 5: Verify imputation applied correctly - check nulls after imputation
SELECT
    COUNT(*) as total_rows,
    COUNT({column_1}) as col1_non_null,
    COUNT(*) - COUNT({column_1}) as col1_null_after,
    CAST((COUNT(*) - COUNT({column_1})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as col1_null_pct_after,
    COUNT({column_2}) as col2_non_null,
    COUNT(*) - COUNT({column_2}) as col2_null_after,
    CAST((COUNT(*) - COUNT({column_2})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as col2_null_pct_after
FROM {output_database}.imputed_data_out;

-- Step 6: Compare before and after statistics
SELECT
    'Original Data' as data_type,
    '{column_1}' as column_name,
    MIN({column_1}) as min_value,
    MAX({column_1}) as max_value,
    AVG({column_1}) as mean_value,
    STDDEV({column_1}) as std_dev,
    COUNT(*) - COUNT({column_1}) as null_count
FROM {test_data_database}.{test_data_table}

UNION ALL

SELECT
    'Imputed Data' as data_type,
    '{column_1}' as column_name,
    MIN({column_1}) as min_value,
    MAX({column_1}) as max_value,
    AVG({column_1}) as mean_value,
    STDDEV({column_1}) as std_dev,
    COUNT(*) - COUNT({column_1}) as null_count
FROM {output_database}.imputed_data_out;

-- Step 7: Data integrity check - no rows lost
SELECT
    'Integrity Check' as check_type,
    (SELECT COUNT(*) FROM {test_data_database}.{test_data_table}) as original_rows,
    (SELECT COUNT(*) FROM {output_database}.imputed_data_out) as imputed_rows,
    CASE
        WHEN (SELECT COUNT(*) FROM {test_data_database}.{test_data_table}) =
             (SELECT COUNT(*) FROM {output_database}.imputed_data_out)
        THEN 'PASS - No Data Loss'
        ELSE 'FAIL - Row Count Mismatch'
    END as integrity_status;

-- Step 8: Identify which rows had values imputed
/*
SELECT
    i.{id_column},
    CASE WHEN o.{column_1} IS NULL THEN 'Imputed' ELSE 'Original' END as col1_status,
    o.{column_1} as original_value,
    i.{column_1} as imputed_value
FROM {output_database}.imputed_data_out i
JOIN {test_data_database}.{test_data_table} o
    ON i.{id_column} = o.{id_column}
WHERE o.{column_1} IS NULL
ORDER BY i.{id_column};
*/

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {model_database} - Database containing fitted imputer
--    {test_data_database} - Database with new data
--    {test_data_table} - Table name for new data
--    {output_database} - Where to store imputed data
--    {id_column} - Unique identifier column
--    {target_columns} - Columns to impute
--    {additional_columns} - Columns to keep but not impute
--    {column_1}, {column_2} - Specific columns for validation
--
-- 2. Prerequisites:
--    - Fitted imputer (TD_SimpleImputeFit output) must exist
--    - New data must have same features as training data
--    - Features must be numeric or categorical
--
-- 3. Imputation methods:
--    - Mean: Replace nulls with mean (numeric only)
--    - Median: Replace nulls with median (numeric only)
--    - Mode: Replace nulls with most frequent value
--    - Constant: Replace nulls with specified constant
--
-- 4. When to use:
--    - Before machine learning models that don't handle nulls
--    - To maintain consistent sample size
--    - When missing data is random (MCAR/MAR)
--    - NOT recommended if missingness is informative (MNAR)
--
-- =====================================================
