-- =====================================================
-- TD_NaiveBayes - Model Training Script
-- =====================================================
-- Purpose: Train Naive Bayes classification model
-- Input: Preprocessed training data
-- Output: Trained Naive Bayes probability model
-- =====================================================

-- Step 1: Verify training data exists and is valid
SELECT
    'Training Data Summary' as check_type,
    COUNT(*) as total_records,
    COUNT(DISTINCT {target_column}) as num_classes,
    COUNT({id_column}) as non_null_ids
FROM {database}.nb_train_test_split
WHERE train_flag = 1;

-- Step 2: Train Naive Bayes model
DROP TABLE IF EXISTS {database}.nb_model_out;
CREATE MULTISET TABLE {database}.nb_model_out AS (
    SELECT * FROM TD_NaiveBayes (
        ON (SELECT * FROM {database}.nb_train_test_split WHERE train_flag = 1) AS InputTable
        USING
        ResponseColumn ('{target_column}')
        InputColumns ({feature_column_list})
        IDColumn ('{id_column}')
        ModelType ('MULTINOMIAL')
        Laplace (1.0)
    ) as dt
) WITH DATA;

-- Step 3: View model statistics
SELECT * FROM {database}.nb_model_out
LIMIT 100;

-- Step 4: Analyze probability distributions
SELECT
    'Naive Bayes Model Summary' as metric_type,
    COUNT(DISTINCT class_name) as num_classes,
    COUNT(DISTINCT feature_name) as num_features
FROM {database}.nb_model_out;

-- =====================================================
-- Model Training Summary Report
-- =====================================================

SELECT
    'Naive Bayes Training Complete' as status,
    (SELECT COUNT(*) FROM {database}.nb_train_test_split WHERE train_flag = 1) as training_samples,
    (SELECT COUNT(DISTINCT class_name) FROM {database}.nb_model_out) as num_classes;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {target_column} - Target classification variable
--    {id_column} - Unique identifier column
--    {feature_column_list} - Comma-separated list of feature columns
--
-- 2. TD_NaiveBayes parameters:
--    - ResponseColumn: Target variable to predict
--    - InputColumns: Features for training
--    - IDColumn: Unique identifier
--    - ModelType: 'MULTINOMIAL', 'BERNOULLI', 'GAUSSIAN'
--    - Laplace: Laplace smoothing parameter
--
-- 3. Next steps:
--    - Proceed to prediction.sql for model evaluation
--
-- =====================================================
