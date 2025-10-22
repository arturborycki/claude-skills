-- =====================================================
-- TD_LogisticRegression - Model Training Script
-- =====================================================
-- Purpose: Train Logistic Regression classification model
-- Input: Preprocessed training data
-- Output: Trained logistic regression coefficients
-- =====================================================

-- Step 1: Verify training data exists and is valid
SELECT
    'Training Data Summary' as check_type,
    COUNT(*) as total_records,
    COUNT(DISTINCT {target_column}) as num_classes,
    COUNT({id_column}) as non_null_ids
FROM {database}.logreg_train_test_split
WHERE train_flag = 1;

-- Step 2: Train Logistic Regression model
DROP TABLE IF EXISTS {database}.logreg_model_out;
CREATE MULTISET TABLE {database}.logreg_model_out AS (
    SELECT * FROM TD_LogisticRegression (
        ON (SELECT * FROM {database}.logreg_train_test_split WHERE train_flag = 1) AS InputTable
        USING
        ResponseColumn ('{target_column}')
        InputColumns ({feature_column_list})
        IDColumn ('{id_column}')
        Family ('BINOMIAL')
        LinkFunction ('LOGIT')
        Intercept ('true')
        MaxIterations (100)
        Tolerance (0.0001)
    ) as dt
) WITH DATA;

-- Step 3: View model coefficients
SELECT * FROM {database}.logreg_model_out
ORDER BY coefficient_name;

-- Step 4: Analyze model statistics
SELECT
    'Logistic Regression Model Summary' as metric_type,
    COUNT(*) as num_coefficients,
    AVG(coefficient_value) as avg_coefficient,
    AVG(std_error) as avg_std_error
FROM {database}.logreg_model_out;

-- =====================================================
-- Model Training Summary Report
-- =====================================================

SELECT
    'Logistic Regression Training Complete' as status,
    (SELECT COUNT(*) FROM {database}.logreg_train_test_split WHERE train_flag = 1) as training_samples,
    (SELECT COUNT(*) FROM {database}.logreg_model_out) as num_coefficients;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {target_column} - Target classification variable
--    {id_column} - Unique identifier column
--    {feature_column_list} - Comma-separated list of feature columns
--
-- 2. TD_LogisticRegression parameters:
--    - ResponseColumn: Target variable to predict
--    - InputColumns: Features for training
--    - IDColumn: Unique identifier
--    - Family: 'BINOMIAL' for binary/multi-class classification
--    - LinkFunction: 'LOGIT' for logistic regression
--    - Intercept: Include intercept term ('true' or 'false')
--    - MaxIterations: Maximum optimization iterations
--    - Tolerance: Convergence tolerance
--
-- 3. Next steps:
--    - Proceed to prediction.sql for model evaluation
--
-- =====================================================
