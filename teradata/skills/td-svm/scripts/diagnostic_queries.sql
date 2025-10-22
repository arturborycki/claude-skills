-- =====================================================
-- Diagnostic Queries - SVM Analysis
-- =====================================================
-- Purpose: Analyze support vectors, rules, and performance
-- Focus: Tree interpretation, feature importance, error analysis
-- =====================================================

-- =====================================================
-- 1. TREE STRUCTURE OVERVIEW
-- =====================================================

-- Overall tree statistics
SELECT
    COUNT(*) as total_nodes,
    SUM(CASE WHEN sv_type = 'Split' THEN 1 ELSE 0 END) as decision_nodes,
    SUM(CASE WHEN sv_type = 'Leaf' THEN 1 ELSE 0 END) as leaf_nodes,
    MAX(depth) as max_depth,
    AVG(CAST(depth AS FLOAT)) as avg_depth,
    MIN(CASE WHEN sv_type = 'Leaf' THEN depth END) as shallowest_leaf,
    MAX(CASE WHEN sv_type = 'Leaf' THEN depth END) as deepest_leaf
FROM {database}.svm_model_out;

-- Nodes per depth level
SELECT
    depth,
    COUNT(*) as sv_count,
    SUM(CASE WHEN sv_type = 'Split' THEN 1 ELSE 0 END) as split_nodes,
    SUM(CASE WHEN sv_type = 'Leaf' THEN 1 ELSE 0 END) as leaf_nodes,
    RPAD('*', COUNT(*), '*') as visual_bar
FROM {database}.svm_model_out
GROUP BY depth
ORDER BY depth;

-- =====================================================
-- 2. FEATURE IMPORTANCE ANALYSIS
-- =====================================================

-- Feature importance based on splitting frequency and margin decrease
SELECT
    support_vector as feature_name,
    COUNT(*) as split_count,
    AVG(margin_decrease) as avg_margin_decrease,
    SUM(margin_decrease) as total_margin_decrease,
    AVG(sample_count) as avg_samples_at_split,
    MIN(depth) as first_split_depth,
    RANK() OVER (ORDER BY SUM(margin_decrease) DESC) as importance_rank
FROM {database}.svm_model_out
WHERE sv_type = 'Split' AND support_vector IS NOT NULL
GROUP BY support_vector
ORDER BY total_margin_decrease DESC;

-- Top 10 most important splits
SELECT
    sv_id,
    depth,
    support_vector,
    split_value,
    margin_decrease,
    margin_index,
    sample_count,
    predicted_class
FROM {database}.svm_model_out
WHERE sv_type = 'Split'
ORDER BY margin_decrease DESC
LIMIT 10;

-- =====================================================
-- 3. DECISION RULES EXTRACTION
-- =====================================================

-- Extract top-level decision rules (depth <= 3)
SELECT
    sv_id,
    depth,
    parent_id,
    sv_type,
    support_vector,
    split_value,
    split_operator,
    margin_index,
    sample_count,
    predicted_class,
    confidence
FROM {database}.svm_model_out
WHERE depth <= 3
ORDER BY depth, sv_id;

-- Leaf node analysis - terminal predictions
SELECT
    sv_id,
    depth,
    predicted_class,
    confidence,
    sample_count,
    margin_index,
    CASE
        WHEN confidence >= 0.95 THEN 'Very High Purity'
        WHEN confidence >= 0.85 THEN 'High Purity'
        WHEN confidence >= 0.70 THEN 'Medium Purity'
        ELSE 'Low Purity'
    END as sv_quality
FROM {database}.svm_model_out
WHERE sv_type = 'Leaf'
ORDER BY sample_count DESC;

-- =====================================================
-- 4. TREE BALANCE AND COMPLEXITY
-- =====================================================

-- Analyze tree balance (left vs right subtrees)
WITH sv_children AS (
    SELECT
        parent_id,
        COUNT(*) as child_count,
        SUM(CASE WHEN sv_type = 'Leaf' THEN 1 ELSE 0 END) as leaf_children
    FROM {database}.svm_model_out
    WHERE parent_id IS NOT NULL
    GROUP BY parent_id
)
SELECT
    CASE
        WHEN child_count = 2 THEN 'Balanced (2 children)'
        WHEN child_count = 1 THEN 'Unbalanced (1 child)'
        ELSE 'Other'
    END as balance_type,
    COUNT(*) as parent_count,
    AVG(leaf_children) as avg_leaf_children
FROM sv_children
GROUP BY 1;

-- Sample distribution across leaf nodes
SELECT
    'Sample Distribution' as metric_type,
    MIN(sample_count) as min_samples_per_leaf,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY sample_count) as q1_samples,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY sample_count) as median_samples,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY sample_count) as q3_samples,
    MAX(sample_count) as max_samples_per_leaf,
    AVG(sample_count) as avg_samples_per_leaf,
    STDDEV(sample_count) as stddev_samples
FROM {database}.svm_model_out
WHERE sv_type = 'Leaf';

-- =====================================================
-- 5. CLASS DISTRIBUTION IN LEAF NODES
-- =====================================================

-- Leaf nodes by predicted class
SELECT
    predicted_class,
    COUNT(*) as leaf_count,
    AVG(confidence) as avg_confidence,
    AVG(sample_count) as avg_samples,
    SUM(sample_count) as total_samples,
    MIN(confidence) as min_confidence,
    MAX(confidence) as max_confidence
FROM {database}.svm_model_out
WHERE sv_type = 'Leaf'
GROUP BY predicted_class
ORDER BY total_samples DESC;

-- Impure leaf nodes (low confidence)
SELECT
    sv_id,
    depth,
    predicted_class,
    confidence,
    margin_index,
    sample_count,
    'Impure leaf - may indicate noise or overlapping classes' as interpretation
FROM {database}.svm_model_out
WHERE sv_type = 'Leaf'
  AND confidence < 0.7
ORDER BY confidence ASC, sample_count DESC;

-- =====================================================
-- 6. PREDICTION ERROR ANALYSIS
-- =====================================================

-- Misclassification analysis by actual class
SELECT
    {target_column} as actual_class,
    prediction as predicted_class,
    COUNT(*) as error_count,
    AVG(confidence) as avg_confidence_when_wrong,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY {target_column}) AS DECIMAL(5,2)) as pct_of_actual
FROM {database}.svm_predictions_out
WHERE {target_column} <> prediction
GROUP BY {target_column}, prediction
ORDER BY error_count DESC;

-- High-confidence errors (model is confident but wrong)
SELECT
    {id_column},
    {target_column} as actual_class,
    prediction as predicted_class,
    confidence,
    'Model confident but incorrect' as issue_type
FROM {database}.svm_predictions_out
WHERE {target_column} <> prediction
  AND confidence >= 0.8
ORDER BY confidence DESC;

-- Low-confidence correct predictions
SELECT
    {id_column},
    {target_column} as actual_class,
    prediction as predicted_class,
    confidence,
    'Correct but uncertain' as note
FROM {database}.svm_predictions_out
WHERE {target_column} = prediction
  AND confidence < 0.6
ORDER BY confidence ASC;

-- =====================================================
-- 7. SPLITTING PATTERNS ANALYSIS
-- =====================================================

-- Most frequently used split points for numeric features
SELECT
    support_vector,
    split_value,
    COUNT(*) as usage_count,
    AVG(margin_decrease) as avg_margin_decrease,
    AVG(depth) as avg_depth_of_use
FROM {database}.svm_model_out
WHERE sv_type = 'Split'
  AND split_value IS NOT NULL
GROUP BY support_vector, split_value
HAVING COUNT(*) > 1
ORDER BY usage_count DESC, avg_margin_decrease DESC;

-- Feature interactions (features used together in same branch)
WITH split_paths AS (
    SELECT
        sv_id,
        depth,
        support_vector,
        LEAD(support_vector, 1) OVER (ORDER BY sv_id) as next_split
    FROM {database}.svm_model_out
    WHERE sv_type = 'Split'
)
SELECT
    support_vector as feature1,
    next_split as feature2,
    COUNT(*) as co_occurrence_count
FROM split_paths
WHERE next_split IS NOT NULL
GROUP BY support_vector, next_split
ORDER BY co_occurrence_count DESC;

-- =====================================================
-- 8. MODEL COMPLEXITY METRICS
-- =====================================================

-- Calculate complexity metrics
WITH tree_stats AS (
    SELECT
        COUNT(*) as total_nodes,
        SUM(CASE WHEN sv_type = 'Leaf' THEN 1 ELSE 0 END) as leaf_count,
        MAX(depth) as tree_depth,
        AVG(CASE WHEN sv_type = 'Leaf' THEN sample_count END) as avg_leaf_samples,
        COUNT(DISTINCT support_vector) as features_used
    FROM {database}.svm_model_out
)
SELECT
    total_nodes,
    leaf_count,
    tree_depth,
    CAST(avg_leaf_samples AS DECIMAL(10,2)) as avg_samples_per_leaf,
    features_used,
    CAST(total_nodes * 1.0 / leaf_count AS DECIMAL(10,2)) as nodes_per_leaf_ratio,
    CASE
        WHEN tree_depth <= 5 THEN 'Low Complexity'
        WHEN tree_depth <= 10 THEN 'Medium Complexity'
        WHEN tree_depth <= 15 THEN 'High Complexity'
        ELSE 'Very High Complexity - Risk of Overfitting'
    END as complexity_assessment
FROM tree_stats;

-- =====================================================
-- 9. PERFORMANCE BY TREE REGION
-- =====================================================

-- Analyze performance for different depths of leaf nodes
SELECT
    depth as leaf_depth,
    COUNT(*) as leaf_count,
    AVG(confidence) as avg_confidence,
    AVG(sample_count) as avg_samples,
    CASE
        WHEN depth <= 5 THEN 'Shallow - General Rules'
        WHEN depth <= 10 THEN 'Medium - Specific Rules'
        ELSE 'Deep - Very Specific Rules'
    END as depth_category
FROM {database}.svm_model_out
WHERE sv_type = 'Leaf'
GROUP BY depth
ORDER BY depth;

-- =====================================================
-- 10. DIAGNOSTIC SUMMARY REPORT
-- =====================================================

SELECT
    'SVM Diagnostic Summary' as report_type,
    (SELECT COUNT(*) FROM {database}.svm_model_out) as total_nodes,
    (SELECT COUNT(*) FROM {database}.svm_model_out WHERE sv_type = 'Leaf') as leaf_nodes,
    (SELECT MAX(depth) FROM {database}.svm_model_out) as max_depth,
    (SELECT COUNT(DISTINCT support_vector) FROM {database}.svm_model_out WHERE sv_type = 'Split') as features_used,
    (SELECT CAST(AVG(CASE WHEN {target_column} = prediction THEN 100.0 ELSE 0.0 END) AS DECIMAL(5,2))
     FROM {database}.svm_predictions_out) as test_accuracy,
    (SELECT AVG(confidence) FROM {database}.svm_predictions_out) as avg_confidence,
    (SELECT COUNT(*) FROM {database}.svm_predictions_out WHERE confidence < 0.6) as low_confidence_predictions;

-- =====================================================
-- Usage Instructions:
-- =====================================================
-- 1. Replace placeholders with actual values
-- 2. Diagnostic workflow:
--    a. Review support vectors and complexity
--    b. Analyze feature importance
--    c. Extract and interpret decision rules
--    d. Identify misclassification patterns
--    e. Assess tree balance and node purity
--
-- 3. Key insights to look for:
--    - Which features are most important?
--    - Is the tree balanced or skewed?
--    - Are there impure leaf nodes (low confidence)?
--    - What are the main decision rules?
--    - Where do misclassifications occur?
--
-- 4. Red flags:
--    - Very deep trees (depth > 15) suggest overfitting
--    - Many impure leaf nodes indicate noisy data
--    - High-confidence errors suggest systematic issues
--    - Unbalanced trees may indicate class imbalance
--
-- =====================================================
