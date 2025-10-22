-- =====================================================
-- Parameter Tuning - TD_GLM Optimization
-- =====================================================
-- Purpose: Systematic approach to optimize GLM parameters
-- Method: Grid search and cross-validation strategies
-- =====================================================

-- =====================================================
-- 1. BASELINE MODEL PERFORMANCE
-- =====================================================

-- Train baseline model with default parameters (Gaussian family)
DROP TABLE IF EXISTS {database}.baseline_model;
CREATE MULTISET TABLE {database}.baseline_model AS (
    SELECT * FROM TD_GLM (
        ON (SELECT * FROM {database}.{train_table} WHERE train_flag = 1) AS InputTable
        USING
        TargetColumn ('{target_column}')
        InputColumns ({feature_columns})
        Family ('Gaussian')
        LinkFunction ('Identity')
        MaxIterNum (20)
        Tolerance (0.01)
    ) as dt
) WITH DATA;

-- Evaluate baseline performance
DROP TABLE IF EXISTS {database}.baseline_predictions;
CREATE MULTISET TABLE {database}.baseline_predictions AS (
    SELECT * FROM TD_GLMPredict (
        ON (SELECT * FROM {database}.{train_table} WHERE train_flag = 0) AS InputTable
        ON {database}.baseline_model AS ModelTable DIMENSION
        USING
        IDColumn ('{id_column}')
        Accumulate ('{id_column}', '{target_column}')
    ) as dt
) WITH DATA;

-- Calculate baseline metrics
SELECT
    'Baseline Model (Gaussian)' as model_version,
    COUNT(*) as n_predictions,
    AVG(POWER(prediction - {target_column}, 2)) as mse,
    SQRT(AVG(POWER(prediction - {target_column}, 2))) as rmse,
    AVG(ABS(prediction - {target_column})) as mae,
    1 - (SUM(POWER(prediction - {target_column}, 2)) /
         SUM(POWER({target_column} - AVG({target_column}) OVER(), 2))) as r_squared
FROM {database}.baseline_predictions;

-- =====================================================
-- 2. FAMILY AND LINK FUNCTION TUNING
-- =====================================================

-- Test Gaussian family with Log link (for positive continuous data)
DROP TABLE IF EXISTS {database}.model_gaussian_log;
CREATE MULTISET TABLE {database}.model_gaussian_log AS (
    SELECT * FROM TD_GLM (
        ON (SELECT * FROM {database}.{train_table} WHERE train_flag = 1) AS InputTable
        USING
        TargetColumn ('{target_column}')
        InputColumns ({feature_columns})
        Family ('Gaussian')
        LinkFunction ('Log')
        MaxIterNum (20)
        Tolerance (0.01)
    ) as dt
) WITH DATA;

-- Test Gamma family (for positive continuous data with constant CV)
DROP TABLE IF EXISTS {database}.model_gamma;
CREATE MULTISET TABLE {database}.model_gamma AS (
    SELECT * FROM TD_GLM (
        ON (SELECT * FROM {database}.{train_table} WHERE train_flag = 1) AS InputTable
        USING
        TargetColumn ('{target_column}')
        InputColumns ({feature_columns})
        Family ('Gamma')
        LinkFunction ('Inverse')
        MaxIterNum (20)
        Tolerance (0.01)
    ) as dt
) WITH DATA;

-- Test Binomial family (for binary classification)
/*
DROP TABLE IF EXISTS {database}.model_binomial;
CREATE MULTISET TABLE {database}.model_binomial AS (
    SELECT * FROM TD_GLM (
        ON (SELECT * FROM {database}.{train_table} WHERE train_flag = 1) AS InputTable
        USING
        TargetColumn ('{target_column}')
        InputColumns ({feature_columns})
        Family ('Binomial')
        LinkFunction ('Logit')
        MaxIterNum (20)
        Tolerance (0.01)
    ) as dt
) WITH DATA;
*/

-- Test Poisson family (for count data)
/*
DROP TABLE IF EXISTS {database}.model_poisson;
CREATE MULTISET TABLE {database}.model_poisson AS (
    SELECT * FROM TD_GLM (
        ON (SELECT * FROM {database}.{train_table} WHERE train_flag = 1) AS InputTable
        USING
        TargetColumn ('{target_column}')
        InputColumns ({feature_columns})
        Family ('Poisson')
        LinkFunction ('Log')
        MaxIterNum (20)
        Tolerance (0.01)
    ) as dt
) WITH DATA;
*/

-- =====================================================
-- 3. CONVERGENCE PARAMETER TUNING
-- =====================================================

-- Test with higher MaxIterNum
DROP TABLE IF EXISTS {database}.model_max_iter50;
CREATE MULTISET TABLE {database}.model_max_iter50 AS (
    SELECT * FROM TD_GLM (
        ON (SELECT * FROM {database}.{train_table} WHERE train_flag = 1) AS InputTable
        USING
        TargetColumn ('{target_column}')
        InputColumns ({feature_columns})
        Family ('Gaussian')
        LinkFunction ('Identity')
        MaxIterNum (50)
        Tolerance (0.01)
    ) as dt
) WITH DATA;

-- Test with stricter tolerance
DROP TABLE IF EXISTS {database}.model_strict_tol;
CREATE MULTISET TABLE {database}.model_strict_tol AS (
    SELECT * FROM TD_GLM (
        ON (SELECT * FROM {database}.{train_table} WHERE train_flag = 1) AS InputTable
        USING
        TargetColumn ('{target_column}')
        InputColumns ({feature_columns})
        Family ('Gaussian')
        LinkFunction ('Identity')
        MaxIterNum (20)
        Tolerance (0.001)
    ) as dt
) WITH DATA;

-- =====================================================
-- 4. FEATURE SUBSET SELECTION
-- =====================================================

-- Test with top features only
DROP TABLE IF EXISTS {database}.model_subset;
CREATE MULTISET TABLE {database}.model_subset AS (
    SELECT * FROM TD_GLM (
        ON (SELECT * FROM {database}.{train_table} WHERE train_flag = 1) AS InputTable
        USING
        TargetColumn ('{target_column}')
        InputColumns ('{feature_1}', '{feature_2}', '{feature_3}')
        Family ('Gaussian')
        LinkFunction ('Identity')
        MaxIterNum (20)
        Tolerance (0.01)
    ) as dt
) WITH DATA;

-- =====================================================
-- 5. REGULARIZATION (if supported)
-- =====================================================

-- Test with Ridge regularization (if available)
/*
DROP TABLE IF EXISTS {database}.model_ridge;
CREATE MULTISET TABLE {database}.model_ridge AS (
    SELECT * FROM TD_GLM (
        ON (SELECT * FROM {database}.{train_table} WHERE train_flag = 1) AS InputTable
        USING
        TargetColumn ('{target_column}')
        InputColumns ({feature_columns})
        Family ('Gaussian')
        LinkFunction ('Identity')
        Alpha (0.5)
        Lambda (0.1)
        MaxIterNum (20)
    ) as dt
) WITH DATA;
*/

-- =====================================================
-- 6. CROSS-VALIDATION APPROACH
-- =====================================================

-- Create k-fold cross-validation splits (k=5 example)
DROP TABLE IF EXISTS {database}.cv_splits;
CREATE MULTISET TABLE {database}.cv_splits AS (
    SELECT
        *,
        MOD(ROW_NUMBER() OVER (ORDER BY {id_column}), 5) + 1 as fold_id
    FROM {database}.{train_table}
) WITH DATA;

-- Train and evaluate on each fold
-- Fold 1
DROP TABLE IF EXISTS {database}.cv_model_fold1;
CREATE MULTISET TABLE {database}.cv_model_fold1 AS (
    SELECT * FROM TD_GLM (
        ON (SELECT * FROM {database}.cv_splits WHERE fold_id <> 1) AS InputTable
        USING
        TargetColumn ('{target_column}')
        InputColumns ({feature_columns})
        Family ('Gaussian')
        LinkFunction ('Identity')
        MaxIterNum (20)
        Tolerance (0.01)
    ) as dt
) WITH DATA;

DROP TABLE IF EXISTS {database}.cv_predictions_fold1;
CREATE MULTISET TABLE {database}.cv_predictions_fold1 AS (
    SELECT
        1 as fold_id,
        dt.*
    FROM TD_GLMPredict (
        ON (SELECT * FROM {database}.cv_splits WHERE fold_id = 1) AS InputTable
        ON {database}.cv_model_fold1 AS ModelTable DIMENSION
        USING
        IDColumn ('{id_column}')
        Accumulate ('{id_column}', '{target_column}')
    ) as dt
) WITH DATA;

-- Repeat for folds 2-5
-- For brevity, showing structure for fold 1 only

-- Aggregate cross-validation results
SELECT
    'Cross-Validation' as validation_type,
    fold_id,
    COUNT(*) as n_predictions,
    SQRT(AVG(POWER(prediction - {target_column}, 2))) as rmse,
    AVG(ABS(prediction - {target_column})) as mae,
    1 - (SUM(POWER(prediction - {target_column}, 2)) /
         SUM(POWER({target_column} - AVG({target_column}) OVER(), 2))) as r_squared
FROM (
    SELECT * FROM {database}.cv_predictions_fold1
    UNION ALL
    SELECT * FROM {database}.cv_predictions_fold2
    UNION ALL
    SELECT * FROM {database}.cv_predictions_fold3
    UNION ALL
    SELECT * FROM {database}.cv_predictions_fold4
    UNION ALL
    SELECT * FROM {database}.cv_predictions_fold5
) combined_folds
GROUP BY fold_id
ORDER BY fold_id;

-- =====================================================
-- 7. MODEL COMPARISON SUMMARY
-- =====================================================

-- Create comparison table of all tuned models
DROP TABLE IF EXISTS {database}.model_comparison;
CREATE MULTISET TABLE {database}.model_comparison AS (
    -- Baseline model
    SELECT
        'Baseline (Gaussian-Identity)' as model_name,
        'Family=Gaussian, Link=Identity' as parameters,
        SQRT(AVG(POWER(prediction - {target_column}, 2))) as rmse,
        AVG(ABS(prediction - {target_column})) as mae,
        1 - (SUM(POWER(prediction - {target_column}, 2)) /
             SUM(POWER({target_column} - AVG({target_column}) OVER(), 2))) as r_squared,
        COUNT(*) as n_test_samples
    FROM {database}.baseline_predictions

    -- Add additional model comparisons here
) WITH DATA;

-- Display ranked models
SELECT
    model_name,
    parameters,
    CAST(rmse AS DECIMAL(10,4)) as rmse,
    CAST(mae AS DECIMAL(10,4)) as mae,
    CAST(r_squared AS DECIMAL(10,6)) as r_squared,
    n_test_samples,
    RANK() OVER (ORDER BY rmse) as rmse_rank,
    RANK() OVER (ORDER BY r_squared DESC) as r_squared_rank
FROM {database}.model_comparison
ORDER BY r_squared DESC;

-- =====================================================
-- 8. BEST MODEL SELECTION AND FINAL TRAINING
-- =====================================================

-- After identifying best parameters, train final model
DROP TABLE IF EXISTS {database}.final_optimized_model;
CREATE MULTISET TABLE {database}.final_optimized_model AS (
    SELECT * FROM TD_GLM (
        ON {database}.{train_table} AS InputTable
        USING
        TargetColumn ('{target_column}')
        InputColumns ({best_feature_columns})
        Family ('{best_family}')
        LinkFunction ('{best_link_function}')
        MaxIterNum ({best_max_iter})
        Tolerance ({best_tolerance})
    ) as dt
) WITH DATA;

-- Validate on holdout test set
DROP TABLE IF EXISTS {database}.final_test_predictions;
CREATE MULTISET TABLE {database}.final_test_predictions AS (
    SELECT * FROM TD_GLMPredict (
        ON {database}.{test_table} AS InputTable
        ON {database}.final_optimized_model AS ModelTable DIMENSION
        USING
        IDColumn ('{id_column}')
        Accumulate ('{id_column}', '{target_column}')
    ) as dt
) WITH DATA;

-- Final model performance report
SELECT
    'Final Optimized Model' as model_version,
    COUNT(*) as n_test_samples,
    CAST(AVG(POWER(prediction - {target_column}, 2)) AS DECIMAL(10,4)) as mse,
    CAST(SQRT(AVG(POWER(prediction - {target_column}, 2))) AS DECIMAL(10,4)) as rmse,
    CAST(AVG(ABS(prediction - {target_column})) AS DECIMAL(10,4)) as mae,
    CAST(1 - (SUM(POWER(prediction - {target_column}, 2)) /
              SUM(POWER({target_column} - AVG({target_column}) OVER(), 2))) AS DECIMAL(10,6)) as r_squared,
    CAST(AVG(ABS((prediction - {target_column}) / NULLIF({target_column}, 0))) * 100 AS DECIMAL(10,2)) as mape_percent
FROM {database}.final_test_predictions;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {train_table} - Training data table
--    {test_table} - Test data table
--    {target_column} - Target variable
--    {feature_columns} - All feature columns
--    {id_column} - Unique identifier
--
-- 2. Parameter tuning workflow:
--    a. Establish baseline performance
--    b. Test different family and link functions
--    c. Tune convergence parameters (MaxIterNum, Tolerance)
--    d. Experiment with feature subsets
--    e. Test regularization (if available)
--    f. Perform cross-validation
--    g. Compare all models
--    h. Train final model with best parameters
--
-- 3. Family selection guidelines:
--    - Gaussian: Continuous outcomes, normal errors
--    - Binomial: Binary/proportion outcomes
--    - Poisson: Count data, rate data
--    - Gamma: Positive continuous, constant coefficient of variation
--
-- 4. Link function selection:
--    - Identity: Direct linear relationship
--    - Log: Multiplicative relationships, positive outcomes
--    - Logit: Binary outcomes (0-1 range)
--    - Inverse: Gamma family default
--
-- =====================================================
