-- =====================================================
-- Parameter Tuning - TD_DecisionForest Optimization
-- =====================================================
-- Purpose: Systematic approach to optimize decision forest parameters
-- Method: Grid search across key hyperparameters
-- =====================================================

-- =====================================================
-- 1. BASELINE MODEL PERFORMANCE
-- =====================================================

-- Train baseline model with default parameters
DROP TABLE IF EXISTS {database}.df_baseline_model;
CREATE MULTISET TABLE {database}.df_baseline_model AS (
    SELECT * FROM TD_DecisionForest (
        ON (SELECT * FROM {database}.df_train_test_split WHERE train_flag = 1) AS InputTable
        USING
        ResponseColumn ('{target_column}')
        InputColumns ({feature_columns})
        IDColumn ('{id_column}')
        MaxDepth (10)
        MinSplitSize (20)
        MinNodeSize (10)
        Measures ('GINI')
    ) as dt
) WITH DATA;

-- Evaluate baseline
DROP TABLE IF EXISTS {database}.df_baseline_predictions;
CREATE MULTISET TABLE {database}.df_baseline_predictions AS (
    SELECT * FROM TD_DecisionForestPredict (
        ON (SELECT * FROM {database}.df_train_test_split WHERE train_flag = 0) AS InputTable
        ON {database}.df_baseline_model AS ModelTable DIMENSION
        USING
        IDColumn ('{id_column}')
        Accumulate ('{id_column}', '{target_column}')
    ) as dt
) WITH DATA;

-- Calculate baseline metrics
SELECT
    'Baseline' as model_version,
    'MaxDepth=10, MinSplit=20, MinNode=10, Measure=GINI' as parameters,
    COUNT(*) as n_predictions,
    CAST(SUM(CASE WHEN {target_column} = prediction THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as accuracy,
    AVG(confidence) as avg_confidence,
    (SELECT MAX(depth) FROM {database}.df_baseline_model) as tree_depth,
    (SELECT COUNT(*) FROM {database}.df_baseline_model WHERE node_type = 'Leaf') as leaf_nodes
FROM {database}.df_baseline_predictions;

-- =====================================================
-- 2. MAX DEPTH TUNING
-- =====================================================

-- Test MaxDepth = 5 (shallow tree)
DROP TABLE IF EXISTS {database}.df_model_depth5;
CREATE MULTISET TABLE {database}.df_model_depth5 AS (
    SELECT * FROM TD_DecisionForest (
        ON (SELECT * FROM {database}.df_train_test_split WHERE train_flag = 1) AS InputTable
        USING
        ResponseColumn ('{target_column}')
        InputColumns ({feature_columns})
        IDColumn ('{id_column}')
        MaxDepth (5)
        MinSplitSize (20)
        MinNodeSize (10)
        Measures ('GINI')
    ) as dt
) WITH DATA;

-- Test MaxDepth = 15 (deeper tree)
DROP TABLE IF EXISTS {database}.df_model_depth15;
CREATE MULTISET TABLE {database}.df_model_depth15 AS (
    SELECT * FROM TD_DecisionForest (
        ON (SELECT * FROM {database}.df_train_test_split WHERE train_flag = 1) AS InputTable
        USING
        ResponseColumn ('{target_column}')
        InputColumns ({feature_columns})
        IDColumn ('{id_column}')
        MaxDepth (15)
        MinSplitSize (20)
        MinNodeSize (10)
        Measures ('GINI')
    ) as dt
) WITH DATA;

-- Test MaxDepth = 20 (very deep tree)
DROP TABLE IF EXISTS {database}.df_model_depth20;
CREATE MULTISET TABLE {database}.df_model_depth20 AS (
    SELECT * FROM TD_DecisionForest (
        ON (SELECT * FROM {database}.df_train_test_split WHERE train_flag = 1) AS InputTable
        USING
        ResponseColumn ('{target_column}')
        InputColumns ({feature_columns})
        IDColumn ('{id_column}')
        MaxDepth (20)
        MinSplitSize (20)
        MinNodeSize (10)
        Measures ('GINI')
    ) as dt
) WITH DATA;

-- Evaluate all depth variations
-- (Repeat prediction and evaluation for each model)

-- =====================================================
-- 3. MIN SPLIT SIZE TUNING
-- =====================================================

-- Test MinSplitSize = 10 (more aggressive splitting)
DROP TABLE IF EXISTS {database}.df_model_split10;
CREATE MULTISET TABLE {database}.df_model_split10 AS (
    SELECT * FROM TD_DecisionForest (
        ON (SELECT * FROM {database}.df_train_test_split WHERE train_flag = 1) AS InputTable
        USING
        ResponseColumn ('{target_column}')
        InputColumns ({feature_columns})
        IDColumn ('{id_column}')
        MaxDepth (10)
        MinSplitSize (10)
        MinNodeSize (5)
        Measures ('GINI')
    ) as dt
) WITH DATA;

-- Test MinSplitSize = 50 (conservative splitting)
DROP TABLE IF EXISTS {database}.df_model_split50;
CREATE MULTISET TABLE {database}.df_model_split50 AS (
    SELECT * FROM TD_DecisionForest (
        ON (SELECT * FROM {database}.df_train_test_split WHERE train_flag = 1) AS InputTable
        USING
        ResponseColumn ('{target_column}')
        InputColumns ({feature_columns})
        IDColumn ('{id_column}')
        MaxDepth (10)
        MinSplitSize (50)
        MinNodeSize (25)
        Measures ('GINI')
    ) as dt
) WITH DATA;

-- =====================================================
-- 4. SPLITTING CRITERION COMPARISON
-- =====================================================

-- Test ENTROPY measure
DROP TABLE IF EXISTS {database}.df_model_entropy;
CREATE MULTISET TABLE {database}.df_model_entropy AS (
    SELECT * FROM TD_DecisionForest (
        ON (SELECT * FROM {database}.df_train_test_split WHERE train_flag = 1) AS InputTable
        USING
        ResponseColumn ('{target_column}')
        InputColumns ({feature_columns})
        IDColumn ('{id_column}')
        MaxDepth (10)
        MinSplitSize (20)
        MinNodeSize (10)
        Measures ('ENTROPY')
    ) as dt
) WITH DATA;

-- Evaluate GINI vs ENTROPY
DROP TABLE IF EXISTS {database}.df_entropy_predictions;
CREATE MULTISET TABLE {database}.df_entropy_predictions AS (
    SELECT * FROM TD_DecisionForestPredict (
        ON (SELECT * FROM {database}.df_train_test_split WHERE train_flag = 0) AS InputTable
        ON {database}.df_model_entropy AS ModelTable DIMENSION
        USING
        IDColumn ('{id_column}')
        Accumulate ('{id_column}', '{target_column}')
    ) as dt
) WITH DATA;

-- =====================================================
-- 5. CROSS-VALIDATION APPROACH
-- =====================================================

-- Create 5-fold cross-validation splits
DROP TABLE IF EXISTS {database}.df_cv_splits;
CREATE MULTISET TABLE {database}.df_cv_splits AS (
    SELECT
        *,
        MOD(ROW_NUMBER() OVER (ORDER BY {id_column}), 5) + 1 as fold_id
    FROM {database}.df_train_test_split
    WHERE train_flag = 1
) WITH DATA;

-- Train and evaluate on each fold (example for fold 1)
DROP TABLE IF EXISTS {database}.df_cv_model_fold1;
CREATE MULTISET TABLE {database}.df_cv_model_fold1 AS (
    SELECT * FROM TD_DecisionForest (
        ON (SELECT * FROM {database}.df_cv_splits WHERE fold_id <> 1) AS InputTable
        USING
        ResponseColumn ('{target_column}')
        InputColumns ({feature_columns})
        IDColumn ('{id_column}')
        MaxDepth (10)
        MinSplitSize (20)
        MinNodeSize (10)
        Measures ('GINI')
    ) as dt
) WITH DATA;

DROP TABLE IF EXISTS {database}.df_cv_predictions_fold1;
CREATE MULTISET TABLE {database}.df_cv_predictions_fold1 AS (
    SELECT
        1 as fold_id,
        dt.*
    FROM TD_DecisionForestPredict (
        ON (SELECT * FROM {database}.df_cv_splits WHERE fold_id = 1) AS InputTable
        ON {database}.df_cv_model_fold1 AS ModelTable DIMENSION
        USING
        IDColumn ('{id_column}')
        Accumulate ('{id_column}', '{target_column}')
    ) as dt
) WITH DATA;

-- Repeat for folds 2-5...

-- =====================================================
-- 6. MODEL COMPARISON SUMMARY
-- =====================================================

-- Compare all tuned models
DROP TABLE IF EXISTS {database}.df_model_comparison;
CREATE MULTISET TABLE {database}.df_model_comparison AS (
    -- Baseline model
    SELECT
        'Baseline' as model_name,
        'MaxDepth=10, MinSplit=20, GINI' as parameters,
        CAST(SUM(CASE WHEN {target_column} = prediction THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as accuracy,
        AVG(confidence) as avg_confidence,
        (SELECT MAX(depth) FROM {database}.df_baseline_model) as tree_depth,
        (SELECT COUNT(*) FROM {database}.df_baseline_model WHERE node_type = 'Leaf') as leaf_nodes
    FROM {database}.df_baseline_predictions

    UNION ALL

    -- Entropy model
    SELECT
        'Entropy' as model_name,
        'MaxDepth=10, MinSplit=20, ENTROPY' as parameters,
        CAST(SUM(CASE WHEN {target_column} = prediction THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as accuracy,
        AVG(confidence) as avg_confidence,
        (SELECT MAX(depth) FROM {database}.df_model_entropy) as tree_depth,
        (SELECT COUNT(*) FROM {database}.df_model_entropy WHERE node_type = 'Leaf') as leaf_nodes
    FROM {database}.df_entropy_predictions

    -- Add additional model comparisons here
) WITH DATA;

-- Display ranked models
SELECT
    model_name,
    parameters,
    accuracy,
    avg_confidence,
    tree_depth,
    leaf_nodes,
    RANK() OVER (ORDER BY accuracy DESC) as accuracy_rank,
    -- Prefer simpler models (fewer leaves) when accuracy is similar
    RANK() OVER (ORDER BY leaf_nodes ASC) as complexity_rank
FROM {database}.df_model_comparison
ORDER BY accuracy DESC, leaf_nodes ASC;

-- =====================================================
-- 7. BEST MODEL SELECTION
-- =====================================================

-- Train final model with optimal parameters
DROP TABLE IF EXISTS {database}.df_final_optimized_model;
CREATE MULTISET TABLE {database}.df_final_optimized_model AS (
    SELECT * FROM TD_DecisionForest (
        ON {database}.df_train_test_split AS InputTable
        USING
        ResponseColumn ('{target_column}')
        InputColumns ({best_feature_columns})
        IDColumn ('{id_column}')
        MaxDepth ({optimal_max_depth})
        MinSplitSize ({optimal_min_split})
        MinNodeSize ({optimal_min_node})
        Measures ('{optimal_measure}')
    ) as dt
) WITH DATA;

-- Final model summary
SELECT
    'Final Optimized Model' as status,
    COUNT(*) as total_nodes,
    SUM(CASE WHEN node_type = 'Leaf' THEN 1 ELSE 0 END) as leaf_nodes,
    MAX(depth) as tree_depth,
    COUNT(DISTINCT split_variable) as features_used
FROM {database}.df_final_optimized_model;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders with actual values
-- 2. Parameter tuning workflow:
--    a. Establish baseline performance
--    b. Tune MaxDepth (controls overfitting)
--    c. Tune MinSplitSize and MinNodeSize (controls granularity)
--    d. Compare GINI vs ENTROPY splitting criteria
--    e. Perform cross-validation for robustness
--    f. Select best model balancing accuracy and complexity
--
-- 3. Key parameters:
--    - MaxDepth: Deeper trees capture more patterns but may overfit
--    - MinSplitSize: Larger values prevent overfitting
--    - MinNodeSize: Larger values create simpler trees
--    - Measures: GINI often performs well, ENTROPY can be better for multi-class
--
-- 4. Model selection criteria:
--    - Highest cross-validated accuracy
--    - Simplest model (fewest leaves) with comparable accuracy
--    - Good performance across all classes (check per-class metrics)
--    - Reasonable tree depth (5-15 typically optimal)
--
-- =====================================================
