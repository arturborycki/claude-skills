-- =====================================================
-- TD_OneHotEncoder - Transform New Data Script
-- =====================================================
-- Purpose: Apply one-hot encoding transformation to new data
-- Input: Fitted encoder and new data
-- Output: One-hot encoded features
-- Note: One-hot encoding is preprocessing, not prediction
-- =====================================================

-- Step 1: Verify encoding schema exists
SELECT * FROM {model_database}.onehot_encoder_out;

-- Step 2: Apply one-hot encoding to new data
-- Note: TD_OneHotEncoder typically needs to be refit on new data
-- or you need to manually apply the same encoding scheme

DROP TABLE IF EXISTS {output_database}.encoded_data_out;
CREATE MULTISET TABLE {output_database}.encoded_data_out AS (
    SELECT * FROM TD_OneHotEncoder (
        ON {test_data_database}.{test_data_table} AS InputTable
        ON {model_database}.onehot_encoder_out AS FitTable DIMENSION
        USING
        TargetColumns ('{categorical_column_1}', '{categorical_column_2}')
        IDColumn ('{id_column}')
        Approach ('Count')  -- or 'Binary'
    ) as dt
) WITH DATA;

-- Alternative: Manual application if needed
/*
DROP TABLE IF EXISTS {output_database}.encoded_data_out;
CREATE MULTISET TABLE {output_database}.encoded_data_out AS (
    SELECT
        t.{id_column},
        t.{numeric_column_1},
        t.{numeric_column_2},
        -- Create binary columns for each category
        CASE WHEN t.{categorical_column_1} = 'category_a' THEN 1 ELSE 0 END as cat1_category_a,
        CASE WHEN t.{categorical_column_1} = 'category_b' THEN 1 ELSE 0 END as cat1_category_b,
        CASE WHEN t.{categorical_column_1} = 'category_c' THEN 1 ELSE 0 END as cat1_category_c,
        CASE WHEN t.{categorical_column_2} = 'value_x' THEN 1 ELSE 0 END as cat2_value_x,
        CASE WHEN t.{categorical_column_2} = 'value_y' THEN 1 ELSE 0 END as cat2_value_y
    FROM {test_data_database}.{test_data_table} t
) WITH DATA;
*/

-- Step 3: View encoded data sample
SELECT TOP 100
    *
FROM {output_database}.encoded_data_out
ORDER BY {id_column};

-- Step 4: Count new encoded columns
SELECT
    COUNT(*) as total_columns
FROM DBC.ColumnsV
WHERE DatabaseName = '{output_database}'
AND TableName = 'encoded_data_out';

-- Compare with original column count
SELECT
    'Original' as table_type,
    COUNT(*) as column_count
FROM DBC.ColumnsV
WHERE DatabaseName = '{test_data_database}'
AND TableName = '{test_data_table}'

UNION ALL

SELECT
    'Encoded' as table_type,
    COUNT(*) as column_count
FROM DBC.ColumnsV
WHERE DatabaseName = '{output_database}'
AND TableName = 'encoded_data_out';

-- Step 5: Verify no data loss
SELECT
    'Data Integrity Check' as check_type,
    (SELECT COUNT(*) FROM {test_data_database}.{test_data_table}) as original_rows,
    (SELECT COUNT(*) FROM {output_database}.encoded_data_out) as encoded_rows,
    CASE
        WHEN (SELECT COUNT(*) FROM {test_data_database}.{test_data_table}) =
             (SELECT COUNT(*) FROM {output_database}.encoded_data_out)
        THEN 'PASS'
        ELSE 'FAIL - Row Count Mismatch'
    END as integrity_status;

-- Step 6: Check for unexpected categories (not seen during fit)
-- These would result in all zeros or nulls in encoded columns
/*
WITH category_presence AS (
    SELECT
        {id_column},
        {categorical_column_1},
        -- Check if any encoded column is 1 for this row
        CASE WHEN (cat1_category_a + cat1_category_b + cat1_category_c) = 0
        THEN 'Unknown Category'
        ELSE 'Known Category'
        END as category_status
    FROM {output_database}.encoded_data_out
)
SELECT
    category_status,
    COUNT(*) as count
FROM category_presence
GROUP BY category_status;
*/

-- Step 7: Summary of encoded columns
-- List all new binary columns created
SELECT
    ColumnName,
    ColumnType
FROM DBC.ColumnsV
WHERE DatabaseName = '{output_database}'
AND TableName = 'encoded_data_out'
AND ColumnName NOT IN (
    SELECT ColumnName
    FROM DBC.ColumnsV
    WHERE DatabaseName = '{test_data_database}'
    AND TableName = '{test_data_table}'
)
ORDER BY ColumnName;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {model_database} - Database containing fitted encoder
--    {test_data_database} - Database with new data
--    {test_data_table} - Table name for new data
--    {output_database} - Where to store encoded data
--    {id_column} - Unique identifier column
--    {categorical_column_1}, {categorical_column_2} - Columns to encode
--
-- 2. Prerequisites:
--    - Fitted one-hot encoder schema must exist
--    - New data should contain same categorical values as training
--    - Unknown categories need handling strategy (ignore, error, or default)
--
-- 3. Output characteristics:
--    - Each categorical value becomes a binary (0/1) column
--    - Sparse representation (many zeros)
--    - Number of columns = sum of unique categories across all encoded columns
--    - Original categorical columns are typically dropped
--
-- 4. Important considerations:
--    - High cardinality features create many columns (dimensionality explosion)
--    - Use for tree-based models (decision tree, random forest)
--    - Not needed for some algorithms (e.g., native categorical support)
--    - Consider target encoding or embedding for very high cardinality
--
-- =====================================================
