-- =====================================================
-- TD_ColumnTransformer - Transform New Data Script
-- =====================================================
-- Purpose: Apply fitted column transformations to new data
-- Input: Fitted transformer parameters and new data
-- Output: Transformed columns
-- Note: This is preprocessing transformation, not prediction
-- =====================================================

-- Step 1: Verify transformation parameters exist
SELECT * FROM {model_database}.column_transformer_out;

-- Step 2: Apply column transformation to new data
DROP TABLE IF EXISTS {output_database}.transformed_data_out;
CREATE MULTISET TABLE {output_database}.transformed_data_out AS (
    SELECT * FROM TD_ColumnTransformer (
        ON {test_data_database}.{test_data_table} AS InputTable
        ON {model_database}.column_transformer_out AS FitTable DIMENSION
        USING
        TargetColumns ({target_columns})
        IDColumn ('{id_column}')
        Accumulate ('{id_column}', '{additional_columns}')
    ) as dt
) WITH DATA;

-- Step 3: View transformed data sample
SELECT TOP 100 * FROM {output_database}.transformed_data_out
ORDER BY {id_column};

-- Step 4: Verify transformation applied correctly
-- Compare original vs transformed data statistics
SELECT
    'Original Data' as data_type,
    COUNT(*) as row_count,
    COUNT(DISTINCT {id_column}) as unique_ids
FROM {test_data_database}.{test_data_table}

UNION ALL

SELECT
    'Transformed Data' as data_type,
    COUNT(*) as row_count,
    COUNT(DISTINCT {id_column}) as unique_ids
FROM {output_database}.transformed_data_out;

-- Step 5: Check column structure changes
SELECT
    'Original Table' as table_type,
    COUNT(*) as column_count
FROM DBC.ColumnsV
WHERE DatabaseName = '{test_data_database}'
AND TableName = '{test_data_table}'

UNION ALL

SELECT
    'Transformed Table' as table_type,
    COUNT(*) as column_count
FROM DBC.ColumnsV
WHERE DatabaseName = '{output_database}'
AND TableName = 'transformed_data_out';

-- Step 6: Data integrity check - no rows lost
SELECT
    'Integrity Check' as check_type,
    (SELECT COUNT(*) FROM {test_data_database}.{test_data_table}) as original_rows,
    (SELECT COUNT(*) FROM {output_database}.transformed_data_out) as transformed_rows,
    CASE
        WHEN (SELECT COUNT(*) FROM {test_data_database}.{test_data_table}) =
             (SELECT COUNT(*) FROM {output_database}.transformed_data_out)
        THEN 'PASS - No Data Loss'
        ELSE 'FAIL - Row Count Mismatch'
    END as integrity_status;

-- Step 7: List new and modified columns
SELECT
    ColumnName,
    ColumnType,
    'New or Modified' as column_status
FROM DBC.ColumnsV
WHERE DatabaseName = '{output_database}'
AND TableName = 'transformed_data_out'
ORDER BY ColumnName;

-- Step 8: Check for null values in transformed columns
/*
SELECT
    '{transformed_column_1}' as column_name,
    COUNT(*) as total_rows,
    COUNT({transformed_column_1}) as non_null_rows,
    COUNT(*) - COUNT({transformed_column_1}) as null_rows,
    CAST((COUNT(*) - COUNT({transformed_column_1})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as null_percentage
FROM {output_database}.transformed_data_out;
*/

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {model_database} - Database containing fitted transformer
--    {test_data_database} - Database with new data
--    {test_data_table} - Table name for new data
--    {output_database} - Where to store transformed data
--    {id_column} - Unique identifier column
--    {target_columns} - Columns to transform
--    {additional_columns} - Columns to keep but not transform
--
-- 2. Prerequisites:
--    - Fitted transformer (TD_ColumnTransformer output) must exist
--    - New data must have same features as training data
--    - Features must be appropriate types for transformation
--
-- 3. Transformation types:
--    - Scaling: MinMax, Z-score, MaxAbs, Robust
--    - Encoding: OneHot, Label, Target encoding
--    - Binning: Equal width, Equal frequency, Custom bins
--    - Mathematical: Log, Sqrt, Power transformations
--
-- 4. When to use:
--    - Complex feature engineering pipelines
--    - Multiple transformations on different column groups
--    - Consistent preprocessing across train/test data
--    - Production deployment of preprocessing logic
--
-- =====================================================
