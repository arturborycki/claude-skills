-- =====================================================
-- TD_SVM - Model Training Script
-- =====================================================
-- Purpose: Train Support Vector Machine classification model
-- Input: Preprocessed training data
-- Output: Trained SVM model with support vectors
-- =====================================================

-- Step 1: Verify training data exists and is valid
SELECT
    'Training Data Summary' as check_type,
    COUNT(*) as total_records,
    COUNT(DISTINCT {target_column}) as num_classes,
    COUNT({id_column}) as non_null_ids
FROM {database}.svm_train_test_split
WHERE train_flag = 1;

-- Step 2: Train SVM model
DROP TABLE IF EXISTS {database}.svm_model_out;
CREATE MULTISET TABLE {database}.svm_model_out AS (
    SELECT * FROM TD_SVM (
        ON (SELECT * FROM {database}.svm_train_test_split WHERE train_flag = 1) AS InputTable
        USING
        ResponseColumn ('{target_column}')
        InputColumns ({feature_column_list})
        IDColumn ('{id_column}')
        KernelType ('LINEAR')
        Cost (1.0)
        Tolerance (0.001)
        MaxIterations (1000)
        Seed (42)
    ) as dt
) WITH DATA;

-- Step 3: View model statistics
SELECT * FROM {database}.svm_model_out
LIMIT 100;

-- Step 4: Analyze support vectors
SELECT
    'SVM Model Summary' as metric_type,
    COUNT(*) as num_support_vectors,
    COUNT(DISTINCT predicted_class) as num_classes
FROM {database}.svm_model_out;

-- =====================================================
-- Model Training Summary Report
-- =====================================================

SELECT
    'SVM Training Complete' as status,
    (SELECT COUNT(*) FROM {database}.svm_train_test_split WHERE train_flag = 1) as training_samples,
    (SELECT COUNT(*) FROM {database}.svm_model_out) as support_vectors;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {target_column} - Target classification variable
--    {id_column} - Unique identifier column
--    {feature_column_list} - Comma-separated list of feature columns
--
-- 2. TD_SVM parameters:
--    - ResponseColumn: Target variable to predict
--    - InputColumns: Features for training
--    - IDColumn: Unique identifier
--    - KernelType: 'LINEAR', 'POLYNOMIAL', 'RBF', 'SIGMOID'
--    - Cost: Regularization parameter (C)
--    - Tolerance: Convergence tolerance
--    - MaxIterations: Maximum training iterations
--    - Seed: Random seed for reproducibility
--
-- 3. Next steps:
--    - Proceed to prediction.sql for model evaluation
--
-- =====================================================
