-- =====================================================
-- TD_LinearRegression - Model Training Script
-- =====================================================
-- Purpose: Train Linear Regression model
-- Input: Preprocessed training data
-- Output: Trained linear regression coefficients
-- =====================================================

-- Step 1: Verify training data exists and is valid
SELECT
    'Training Data Summary' as check_type,
    COUNT(*) as total_records,
    AVG({target_column}) as avg_target,
    STDDEV({target_column}) as stddev_target,
    COUNT({id_column}) as non_null_ids
FROM {database}.lr_train_test_split
WHERE train_flag = 1;

-- Step 2: Train Linear Regression model
DROP TABLE IF EXISTS {database}.lr_model_out;
CREATE MULTISET TABLE {database}.lr_model_out AS (
    SELECT * FROM TD_LinearRegression (
        ON (SELECT * FROM {database}.lr_train_test_split WHERE train_flag = 1) AS InputTable
        USING
        TargetColumn ('{target_column}')
        InputColumns ({feature_column_list})
        IDColumn ('{id_column}')
        Intercept ('true')
        Family ('GAUSSIAN')
    ) as dt
) WITH DATA;

-- Step 3: View model coefficients
SELECT * FROM {database}.lr_model_out
ORDER BY coefficient_name;

-- Step 4: Analyze model statistics
SELECT
    'Linear Regression Model Summary' as metric_type,
    COUNT(*) as num_coefficients,
    AVG(coefficient_value) as avg_coefficient
FROM {database}.lr_model_out;

-- =====================================================
-- Model Training Summary Report
-- =====================================================

SELECT
    'Linear Regression Training Complete' as status,
    (SELECT COUNT(*) FROM {database}.lr_train_test_split WHERE train_flag = 1) as training_samples,
    (SELECT COUNT(*) FROM {database}.lr_model_out) as num_coefficients;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {target_column} - Target numeric variable
--    {id_column} - Unique identifier column
--    {feature_column_list} - Comma-separated list of feature columns
--
-- 2. TD_LinearRegression parameters:
--    - TargetColumn: Target variable to predict
--    - InputColumns: Features for training
--    - IDColumn: Unique identifier
--    - Intercept: Include intercept term ('true' or 'false')
--    - Family: Distribution family ('GAUSSIAN' for normal linear regression)
--
-- 3. Next steps:
--    - Proceed to prediction.sql for model evaluation
--
-- =====================================================
