-- =====================================================
-- TD_TrainTestSplit - Data Splitting Script
-- =====================================================
-- Purpose: Split data into training and testing sets
-- Input: Source data table
-- Output: Separate train and test tables
-- Note: This is a one-time operation, not a transform/predict workflow
-- =====================================================

-- Step 1: Verify source data exists
SELECT
    COUNT(*) as total_rows,
    COUNT(DISTINCT {id_column}) as unique_ids
FROM {source_database}.{source_table};

-- Step 2: Perform train-test split
DROP TABLE IF EXISTS {output_database}.train_data_out;
DROP TABLE IF EXISTS {output_database}.test_data_out;

CREATE MULTISET TABLE {output_database}.train_test_out AS (
    SELECT * FROM TD_TrainTestSplit (
        ON {source_database}.{source_table} AS InputTable
        USING
        IDColumn ('{id_column}')
        TrainSize ({train_size})  -- e.g., 0.7 for 70% train, 30% test
        TestSize ({test_size})    -- e.g., 0.3
        Seed ({random_seed})      -- e.g., 42 for reproducibility
        StratifyColumns ('{stratify_column}')  -- Optional: for balanced splits
    ) as dt
) WITH DATA;

-- Step 3: Create separate train and test tables
CREATE MULTISET TABLE {output_database}.train_data_out AS (
    SELECT * FROM {output_database}.train_test_out
    WHERE split_column = 'train'
) WITH DATA;

CREATE MULTISET TABLE {output_database}.test_data_out AS (
    SELECT * FROM {output_database}.train_test_out
    WHERE split_column = 'test'
) WITH DATA;

-- Step 4: Verify split sizes
SELECT
    'Overall Statistics' as check_type,
    (SELECT COUNT(*) FROM {source_database}.{source_table}) as total_original,
    (SELECT COUNT(*) FROM {output_database}.train_data_out) as train_count,
    (SELECT COUNT(*) FROM {output_database}.test_data_out) as test_count,
    (SELECT COUNT(*) FROM {output_database}.train_data_out) +
    (SELECT COUNT(*) FROM {output_database}.test_data_out) as total_split,
    CAST((SELECT COUNT(*) FROM {output_database}.train_data_out) * 100.0 /
         (SELECT COUNT(*) FROM {source_database}.{source_table}) AS DECIMAL(5,2)) as train_percentage,
    CAST((SELECT COUNT(*) FROM {output_database}.test_data_out) * 100.0 /
         (SELECT COUNT(*) FROM {source_database}.{source_table}) AS DECIMAL(5,2)) as test_percentage;

-- Step 5: Verify no data loss or duplication
SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM {source_database}.{source_table}) =
             ((SELECT COUNT(*) FROM {output_database}.train_data_out) +
              (SELECT COUNT(*) FROM {output_database}.test_data_out))
        THEN 'PASS - Perfect Split'
        WHEN (SELECT COUNT(*) FROM {source_database}.{source_table}) <
             ((SELECT COUNT(*) FROM {output_database}.train_data_out) +
              (SELECT COUNT(*) FROM {output_database}.test_data_out))
        THEN 'FAIL - Duplicates Detected'
        ELSE 'FAIL - Data Loss Detected'
    END as integrity_status,
    (SELECT COUNT(*) FROM {source_database}.{source_table}) as original_count,
    ((SELECT COUNT(*) FROM {output_database}.train_data_out) +
     (SELECT COUNT(*) FROM {output_database}.test_data_out)) as total_after_split;

-- Step 6: Check for overlapping IDs (should be zero)
SELECT
    COUNT(*) as overlapping_ids,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS - No Overlap'
        ELSE 'FAIL - IDs Found in Both Sets'
    END as overlap_status
FROM {output_database}.train_data_out train
INNER JOIN {output_database}.test_data_out test
    ON train.{id_column} = test.{id_column};

-- Step 7: Verify stratification (if used)
-- Check if target variable distribution is similar in train and test
/*
SELECT
    'Train Set' as dataset,
    {stratify_column} as category,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {output_database}.train_data_out
GROUP BY {stratify_column}

UNION ALL

SELECT
    'Test Set' as dataset,
    {stratify_column} as category,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {output_database}.test_data_out
GROUP BY {stratify_column}

ORDER BY dataset, category;
*/

-- Step 8: Summary statistics by dataset
SELECT
    'Training Set' as dataset,
    COUNT(*) as row_count,
    AVG({numeric_column_1}) as avg_col1,
    STDDEV({numeric_column_1}) as std_col1,
    MIN({numeric_column_1}) as min_col1,
    MAX({numeric_column_1}) as max_col1
FROM {output_database}.train_data_out

UNION ALL

SELECT
    'Test Set' as dataset,
    COUNT(*) as row_count,
    AVG({numeric_column_1}) as avg_col1,
    STDDEV({numeric_column_1}) as std_col1,
    MIN({numeric_column_1}) as min_col1,
    MAX({numeric_column_1}) as max_col1
FROM {output_database}.test_data_out;

-- Step 9: View sample from each set
SELECT 'Training Set Sample' as dataset, * FROM {output_database}.train_data_out
ORDER BY {id_column}
LIMIT 10;

SELECT 'Test Set Sample' as dataset, * FROM {output_database}.test_data_out
ORDER BY {id_column}
LIMIT 10;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {source_database} - Database containing source data
--    {source_table} - Source table name
--    {output_database} - Where to store train/test tables
--    {id_column} - Unique identifier column
--    {train_size} - Training set proportion (e.g., 0.7)
--    {test_size} - Test set proportion (e.g., 0.3)
--    {random_seed} - Random seed for reproducibility
--    {stratify_column} - Column for stratified sampling (optional)
--    {numeric_column_1} - Example numeric column for validation
--
-- 2. Prerequisites:
--    - Source data table must exist
--    - ID column should be unique
--    - train_size + test_size should equal 1.0
--
-- 3. Split strategies:
--    - Random: Simple random split
--    - Stratified: Maintains class distribution (for classification)
--    - Time-based: Use date/time column for temporal data (not standard in TD_TrainTestSplit)
--
-- 4. Best practices:
--    - Use stratification for imbalanced classification problems
--    - Common splits: 70/30, 80/20, 60/20/20 (with validation set)
--    - Always use a fixed seed for reproducibility
--    - Verify no data leakage between sets
--
-- 5. Important notes:
--    - This is a one-time split, not a fit/transform operation
--    - No separate "prediction" step needed
--    - Consider creating validation set for hyperparameter tuning
--
-- =====================================================
