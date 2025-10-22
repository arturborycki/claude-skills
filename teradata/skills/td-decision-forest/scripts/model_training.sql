-- =====================================================
-- TD_DecisionForest - Model Training Script
-- =====================================================
-- Purpose: Train decision forest classification model
-- Input: Preprocessed training data
-- Output: Trained model table with tree structure
-- =====================================================

-- Step 1: Verify training data exists and is valid
SELECT
    'Training Data Summary' as check_type,
    COUNT(*) as total_records,
    COUNT(DISTINCT {target_column}) as num_classes,
    COUNT({id_column}) as non_null_ids
FROM {database}.df_train_test_split
WHERE train_flag = 1;

-- Step 2: Train baseline decision forest model
DROP TABLE IF EXISTS {database}.df_model_out;
CREATE MULTISET TABLE {database}.df_model_out AS (
    SELECT * FROM TD_DecisionForest (
        ON (SELECT * FROM {database}.df_train_test_split WHERE train_flag = 1) AS InputTable
        USING
        ResponseColumn ('{target_column}')
        InputColumns ({feature_column_list})
        IDColumn ('{id_column}')
        MaxDepth (10)
        MinSplitSize (20)
        MinNodeSize (10)
        NumSplits (10)
        Measures ('GINI')
        Seed (42)
    ) as dt
) WITH DATA;

-- Step 3: View model structure and statistics
SELECT * FROM {database}.df_model_out
ORDER BY node_id;

-- Step 4: Analyze tree structure
SELECT
    'Tree Structure Summary' as metric_type,
    COUNT(*) as total_nodes,
    SUM(CASE WHEN node_type = 'Leaf' THEN 1 ELSE 0 END) as leaf_nodes,
    SUM(CASE WHEN node_type = 'Split' THEN 1 ELSE 0 END) as split_nodes,
    MAX(depth) as max_depth,
    AVG(CAST(depth AS FLOAT)) as avg_depth
FROM {database}.df_model_out;

-- Step 5: View most important splitting variables
SELECT
    split_variable,
    COUNT(*) as split_count,
    AVG(gini_decrease) as avg_gini_decrease,
    SUM(gini_decrease) as total_gini_decrease
FROM {database}.df_model_out
WHERE node_type = 'Split'
GROUP BY split_variable
ORDER BY total_gini_decrease DESC;

-- Step 6: Examine root node and top-level splits
SELECT
    node_id,
    depth,
    node_type,
    split_variable,
    split_value,
    gini_index,
    sample_count,
    predicted_class
FROM {database}.df_model_out
WHERE depth <= 2
ORDER BY node_id;

-- Step 7: Analyze leaf node class distributions
SELECT
    predicted_class,
    COUNT(*) as leaf_count,
    AVG(confidence) as avg_confidence,
    MIN(confidence) as min_confidence,
    MAX(confidence) as max_confidence,
    AVG(sample_count) as avg_samples_per_leaf
FROM {database}.df_model_out
WHERE node_type = 'Leaf'
GROUP BY predicted_class
ORDER BY leaf_count DESC;

-- =====================================================
-- Model Training Summary Report
-- =====================================================

SELECT
    'Decision Forest Training Complete' as status,
    (SELECT COUNT(*) FROM {database}.df_train_test_split WHERE train_flag = 1) as training_samples,
    (SELECT COUNT(*) FROM {database}.df_model_out) as total_nodes,
    (SELECT COUNT(*) FROM {database}.df_model_out WHERE node_type = 'Leaf') as leaf_nodes,
    (SELECT MAX(depth) FROM {database}.df_model_out) as tree_depth,
    (SELECT COUNT(DISTINCT split_variable) FROM {database}.df_model_out WHERE node_type = 'Split') as features_used;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {target_column} - Target classification variable
--    {id_column} - Unique identifier column
--    {feature_column_list} - Comma-separated list of feature columns
--
-- 2. TD_DecisionForest parameters:
--    - ResponseColumn: Target variable to predict
--    - InputColumns: Features for building tree
--    - IDColumn: Unique identifier for tracking
--    - MaxDepth: Maximum tree depth (default 10)
--    - MinSplitSize: Minimum samples to attempt split (default 20)
--    - MinNodeSize: Minimum samples in leaf node (default 10)
--    - NumSplits: Number of split points to evaluate (default 10)
--    - Measures: Splitting criterion ('GINI' or 'ENTROPY')
--    - Seed: Random seed for reproducibility
--
-- 3. Model output interpretation:
--    - node_id: Unique identifier for each node
--    - node_type: 'Split' (decision node) or 'Leaf' (terminal node)
--    - split_variable: Feature used for splitting
--    - split_value: Threshold value for split
--    - gini_index: Impurity measure at node
--    - predicted_class: Class prediction at leaf nodes
--    - confidence: Prediction confidence (probability)
--
-- 4. Next steps:
--    - Review tree structure and depth
--    - Check feature importance
--    - Proceed to prediction.sql for model evaluation
--
-- =====================================================
