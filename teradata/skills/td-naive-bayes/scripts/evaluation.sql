-- =====================================================
-- Model Evaluation - Classification Metrics
-- =====================================================
-- Purpose: Comprehensive evaluation of naive bayes classifier
-- Metrics: Accuracy, Precision, Recall, F1-Score, Confusion Matrix
-- =====================================================

-- =====================================================
-- 1. CONFUSION MATRIX
-- =====================================================

-- Generate confusion matrix
SELECT
    {target_column} as actual_class,
    prediction as predicted_class,
    COUNT(*) as count
FROM {database}.nb_predictions_out
GROUP BY {target_column}, prediction
ORDER BY actual_class, predicted_class;

-- Confusion matrix with percentages
SELECT
    {target_column} as actual_class,
    prediction as predicted_class,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as pct_of_total,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY {target_column}) AS DECIMAL(5,2)) as pct_of_actual
FROM {database}.nb_predictions_out
GROUP BY {target_column}, prediction
ORDER BY actual_class, predicted_class;

-- =====================================================
-- 2. OVERALL ACCURACY METRICS
-- =====================================================

SELECT
    'Overall Metrics' as metric_category,
    COUNT(*) as total_samples,
    SUM(CASE WHEN {target_column} = prediction THEN 1 ELSE 0 END) as correct_predictions,
    CAST(SUM(CASE WHEN {target_column} = prediction THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as accuracy,
    CAST(SUM(CASE WHEN {target_column} <> prediction THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as error_rate,
    AVG(confidence) as avg_confidence
FROM {database}.nb_predictions_out;

-- =====================================================
-- 3. PER-CLASS METRICS (Precision, Recall, F1-Score)
-- =====================================================

-- Calculate precision, recall, and F1-score for each class
WITH class_metrics AS (
    SELECT
        {target_column} as class_label,
        -- True Positives
        SUM(CASE WHEN {target_column} = prediction THEN 1 ELSE 0 END) as tp,
        -- False Negatives
        SUM(CASE WHEN {target_column} <> prediction THEN 1 ELSE 0 END) as fn,
        -- False Positives (predictions for this class that were wrong)
        (SELECT COUNT(*)
         FROM {database}.nb_predictions_out p2
         WHERE p2.prediction = p1.{target_column}
           AND p2.{target_column} <> p2.prediction) as fp
    FROM {database}.nb_predictions_out p1
    GROUP BY {target_column}
)
SELECT
    class_label,
    tp as true_positives,
    fn as false_negatives,
    fp as false_positives,
    (tp + fp) as total_predicted,
    (tp + fn) as total_actual,
    -- Precision: TP / (TP + FP)
    CAST(CASE WHEN (tp + fp) > 0 THEN tp * 100.0 / (tp + fp) ELSE 0 END AS DECIMAL(5,2)) as precision,
    -- Recall: TP / (TP + FN)
    CAST(CASE WHEN (tp + fn) > 0 THEN tp * 100.0 / (tp + fn) ELSE 0 END AS DECIMAL(5,2)) as recall,
    -- F1-Score: 2 * (Precision * Recall) / (Precision + Recall)
    CAST(CASE
        WHEN (tp + fp) > 0 AND (tp + fn) > 0 THEN
            2.0 * (tp * 1.0 / (tp + fp)) * (tp * 1.0 / (tp + fn)) /
            ((tp * 1.0 / (tp + fp)) + (tp * 1.0 / (tp + fn))) * 100
        ELSE 0
    END AS DECIMAL(5,2)) as f1_score
FROM class_metrics
ORDER BY class_label;

-- =====================================================
-- 4. MACRO AND WEIGHTED AVERAGES
-- =====================================================

-- Calculate macro-averaged metrics (unweighted average across classes)
WITH class_metrics AS (
    SELECT
        {target_column} as class_label,
        SUM(CASE WHEN {target_column} = prediction THEN 1 ELSE 0 END) as tp,
        SUM(CASE WHEN {target_column} <> prediction THEN 1 ELSE 0 END) as fn,
        (SELECT COUNT(*)
         FROM {database}.nb_predictions_out p2
         WHERE p2.prediction = p1.{target_column}
           AND p2.{target_column} <> p2.prediction) as fp
    FROM {database}.nb_predictions_out p1
    GROUP BY {target_column}
),
per_class_metrics AS (
    SELECT
        class_label,
        tp,
        fn,
        fp,
        (tp + fn) as class_support,
        CASE WHEN (tp + fp) > 0 THEN tp * 1.0 / (tp + fp) ELSE 0 END as precision,
        CASE WHEN (tp + fn) > 0 THEN tp * 1.0 / (tp + fn) ELSE 0 END as recall
    FROM class_metrics
)
SELECT
    'Macro Average' as metric_type,
    CAST(AVG(precision) * 100 AS DECIMAL(5,2)) as avg_precision,
    CAST(AVG(recall) * 100 AS DECIMAL(5,2)) as avg_recall,
    CAST(2.0 * AVG(precision) * AVG(recall) / (AVG(precision) + AVG(recall)) * 100 AS DECIMAL(5,2)) as avg_f1_score
FROM per_class_metrics

UNION ALL

-- Calculate weighted average (weighted by class support)
SELECT
    'Weighted Average' as metric_type,
    CAST(SUM(precision * class_support) / SUM(class_support) * 100 AS DECIMAL(5,2)) as avg_precision,
    CAST(SUM(recall * class_support) / SUM(class_support) * 100 AS DECIMAL(5,2)) as avg_recall,
    CAST(SUM(2.0 * precision * recall / (precision + recall) * class_support) / SUM(class_support) * 100 AS DECIMAL(5,2)) as avg_f1_score
FROM per_class_metrics;

-- =====================================================
-- 5. CONFIDENCE-BASED METRICS
-- =====================================================

-- Accuracy by confidence level
SELECT
    CASE
        WHEN confidence >= 0.9 THEN '0.90-1.00'
        WHEN confidence >= 0.8 THEN '0.80-0.90'
        WHEN confidence >= 0.7 THEN '0.70-0.80'
        WHEN confidence >= 0.6 THEN '0.60-0.70'
        ELSE '0.00-0.60'
    END as confidence_range,
    COUNT(*) as sample_count,
    SUM(CASE WHEN {target_column} = prediction THEN 1 ELSE 0 END) as correct,
    CAST(SUM(CASE WHEN {target_column} = prediction THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as accuracy_pct,
    AVG(confidence) as avg_confidence
FROM {database}.nb_predictions_out
GROUP BY 1
ORDER BY avg_confidence DESC;

-- =====================================================
-- 6. MODEL PERFORMANCE SUMMARY
-- =====================================================

SELECT
    'Naive Bayes Evaluation Summary' as report_type,
    (SELECT COUNT(*) FROM {database}.nb_predictions_out) as total_test_samples,
    (SELECT COUNT(DISTINCT {target_column}) FROM {database}.nb_predictions_out) as num_classes,
    (SELECT CAST(AVG(CASE WHEN {target_column} = prediction THEN 100.0 ELSE 0.0 END) AS DECIMAL(5,2))
     FROM {database}.nb_predictions_out) as overall_accuracy,
    (SELECT AVG(confidence) FROM {database}.nb_predictions_out) as avg_prediction_confidence,
    (SELECT MAX(depth) FROM {database}.nb_model_out) as tree_depth,
    (SELECT COUNT(*) FROM {database}.nb_model_out WHERE node_type = 'Leaf') as leaf_nodes;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {target_column} - Target classification variable
--
-- 2. Metrics interpretation:
--    - Accuracy: Overall correctness (good for balanced datasets)
--    - Precision: Of predicted positives, how many are correct
--    - Recall: Of actual positives, how many were found
--    - F1-Score: Harmonic mean of precision and recall
--    - Macro Average: Treats all classes equally
--    - Weighted Average: Accounts for class imbalance
--
-- 3. Performance guidelines:
--    - Accuracy >80%: Good performance
--    - Accuracy >90%: Excellent performance
--    - Check per-class metrics for imbalanced datasets
--    - High confidence with low accuracy indicates overfitting
--
-- 4. Next steps:
--    - If performance is poor, proceed to parameter_tuning.sql
--    - Review diagnostic_queries.sql for detailed analysis
--    - Consider feature engineering or data quality improvements
--
-- =====================================================
