-- =====================================================
-- Data Preprocessing for TD_LogisticRegression
-- =====================================================
-- Purpose: Prepare data for logistic regression classification
-- Operations: Train-test split, encoding, validation
-- =====================================================

-- =====================================================
-- 1. DATA QUALITY VALIDATION
-- =====================================================

-- Check basic data quality
SELECT
    COUNT(*) as total_records,
    COUNT(DISTINCT {id_column}) as unique_ids,
    COUNT({target_column}) as non_null_targets,
    COUNT(DISTINCT {target_column}) as unique_classes,
    CAST((COUNT(*) - COUNT({target_column})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as target_null_pct
FROM {database}.{table_name};

-- Analyze class distribution
SELECT
    {target_column} as class_label,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {database}.{table_name}
WHERE {target_column} IS NOT NULL
GROUP BY {target_column}
ORDER BY count DESC;

-- =====================================================
-- 2. TRAIN-TEST SPLIT
-- =====================================================

-- Create stratified train-test split (70-30)
DROP TABLE IF EXISTS {database}.logreg_train_test_split;
CREATE MULTISET TABLE {database}.logreg_train_test_split AS (
    SELECT
        *,
        CASE
            WHEN RANDOM(1, 100) <= 70 THEN 1
            ELSE 0
        END as train_flag
    FROM {database}.{table_name}
    WHERE {target_column} IS NOT NULL
) WITH DATA;

-- Verify split distribution
SELECT
    train_flag,
    CASE WHEN train_flag = 1 THEN 'Training' ELSE 'Testing' END as dataset,
    COUNT(*) as record_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {database}.logreg_train_test_split
GROUP BY train_flag
ORDER BY train_flag;

-- Verify class balance in splits
SELECT
    train_flag,
    {target_column} as class_label,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY train_flag) AS DECIMAL(5,2)) as pct_within_split
FROM {database}.logreg_train_test_split
GROUP BY train_flag, {target_column}
ORDER BY train_flag, class_label;

-- =====================================================
-- 3. FEATURE VALIDATION
-- =====================================================

-- Check numeric features for issues
SELECT
    'Numeric Features Check' as validation_type,
    COUNT(*) as total_records,
    COUNT({numeric_feature_1}) as non_null_count,
    AVG({numeric_feature_1}) as mean_value,
    STDDEV({numeric_feature_1}) as std_dev,
    MIN({numeric_feature_1}) as min_value,
    MAX({numeric_feature_1}) as max_value
FROM {database}.logreg_train_test_split
WHERE train_flag = 1;

-- Check categorical features cardinality
SELECT
    '{categorical_feature_1}' as feature_name,
    COUNT(DISTINCT {categorical_feature_1}) as unique_values,
    COUNT(*) as total_records,
    CAST(COUNT(DISTINCT {categorical_feature_1}) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as cardinality_ratio
FROM {database}.logreg_train_test_split
WHERE train_flag = 1;

-- =====================================================
-- 4. CATEGORICAL ENCODING (if needed)
-- =====================================================

-- One-hot encode categorical variables if necessary
-- Decision trees can handle categorical data directly in most cases
-- This section is optional depending on your Teradata version

-- Example: Create dummy variables for a categorical feature
/*
DROP TABLE IF EXISTS {database}.logreg_encoded_data;
CREATE MULTISET TABLE {database}.logreg_encoded_data AS (
    SELECT
        t.*,
        CASE WHEN {categorical_feature} = 'category1' THEN 1 ELSE 0 END as cat_category1,
        CASE WHEN {categorical_feature} = 'category2' THEN 1 ELSE 0 END as cat_category2,
        CASE WHEN {categorical_feature} = 'category3' THEN 1 ELSE 0 END as cat_category3
    FROM {database}.logreg_train_test_split t
) WITH DATA;
*/

-- =====================================================
-- 5. MISSING VALUE HANDLING
-- =====================================================

-- Check for missing values in features
SELECT
    COUNT(*) as total_records,
    SUM(CASE WHEN {numeric_feature_1} IS NULL THEN 1 ELSE 0 END) as null_feature1,
    SUM(CASE WHEN {numeric_feature_2} IS NULL THEN 1 ELSE 0 END) as null_feature2,
    SUM(CASE WHEN {categorical_feature_1} IS NULL THEN 1 ELSE 0 END) as null_cat1
FROM {database}.logreg_train_test_split
WHERE train_flag = 1;

-- Optional: Impute missing values if needed
-- Decision trees handle missing values well, but explicit handling may improve performance
/*
DROP TABLE IF EXISTS {database}.logreg_preprocessed;
CREATE MULTISET TABLE {database}.logreg_preprocessed AS (
    SELECT
        {id_column},
        {target_column},
        train_flag,
        COALESCE({numeric_feature_1}, AVG({numeric_feature_1}) OVER()) as {numeric_feature_1},
        COALESCE({numeric_feature_2}, AVG({numeric_feature_2}) OVER()) as {numeric_feature_2},
        COALESCE({categorical_feature_1}, 'UNKNOWN') as {categorical_feature_1}
    FROM {database}.logreg_train_test_split
) WITH DATA;
*/

-- =====================================================
-- 6. FINAL PREPROCESSING SUMMARY
-- =====================================================

-- Generate preprocessing summary report
SELECT
    'Preprocessing Complete' as status,
    COUNT(*) as total_records,
    SUM(CASE WHEN train_flag = 1 THEN 1 ELSE 0 END) as training_records,
    SUM(CASE WHEN train_flag = 0 THEN 1 ELSE 0 END) as testing_records,
    COUNT(DISTINCT {target_column}) as num_classes,
    COUNT(*) - COUNT({target_column}) as missing_targets
FROM {database}.logreg_train_test_split;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {table_name} - Source table name
--    {id_column} - Unique identifier column
--    {target_column} - Target classification variable
--    {numeric_feature_1}, {numeric_feature_2} - Numeric features
--    {categorical_feature_1} - Categorical features
--
-- 2. Decision tree preprocessing notes:
--    - Decision trees handle mixed data types naturally
--    - Scaling is NOT required for logistic regressions
--    - Categorical encoding may not be necessary
--    - Trees handle missing values through surrogate splits
--    - Class imbalance should be addressed if severe
--
-- 3. Next steps:
--    - Review class distribution and balance
--    - Proceed to model_training.sql
--    - Use logreg_train_test_split table for modeling
--
-- =====================================================
