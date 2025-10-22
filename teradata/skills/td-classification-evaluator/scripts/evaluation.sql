-- =====================================================
-- TD_ClassificationEvaluator - Evaluation Script
-- =====================================================
-- Purpose: Calculate classification metrics using TD_ClassificationEvaluator
-- Metrics: Accuracy, Precision, Recall, F1-Score, Confusion Matrix
-- =====================================================

-- Execute TD_ClassificationEvaluator
DROP TABLE IF EXISTS {database}.classification_metrics;
CREATE MULTISET TABLE {database}.classification_metrics AS (
    SELECT * FROM TD_ClassificationEvaluator (
        ON {database}.classification_evaluation_input AS InputTable
        USING
        ObservationColumn ('actual_label')
        PredictionColumn ('predicted_label')
        Classes ('ALL')  -- Or specify: ('class1', 'class2', 'class3')
        Metrics ('ALL')  -- Accuracy, Precision, Recall, F1
    ) as dt
) WITH DATA;

-- Display all metrics
SELECT * FROM {database}.classification_metrics
ORDER BY class_label, metric_name;

-- Extract overall accuracy
SELECT
    metric_name,
    CAST(metric_value AS DECIMAL(8,4)) as metric_value
FROM {database}.classification_metrics
WHERE metric_name = 'Accuracy';

-- Extract per-class metrics
SELECT
    class_label,
    metric_name,
    CAST(metric_value AS DECIMAL(8,4)) as metric_value
FROM {database}.classification_metrics
WHERE metric_name IN ('Precision', 'Recall', 'F1')
ORDER BY class_label, metric_name;

-- Confusion matrix
SELECT
    actual_class,
    predicted_class,
    count
FROM {database}.classification_metrics
WHERE metric_name = 'ConfusionMatrix'
ORDER BY actual_class, predicted_class;

-- Model performance summary
SELECT
    'Classification Model Summary' as report_title,
    (SELECT COUNT(*) FROM {database}.classification_evaluation_input) as n_observations,
    (SELECT COUNT(DISTINCT actual_label) FROM {database}.classification_evaluation_input) as n_classes,
    (SELECT CAST(metric_value AS DECIMAL(8,4)) FROM {database}.classification_metrics WHERE metric_name = 'Accuracy') as accuracy,
    (SELECT AVG(CAST(metric_value AS DECIMAL(8,4))) FROM {database}.classification_metrics WHERE metric_name = 'F1') as macro_avg_f1,
    CASE
        WHEN (SELECT CAST(metric_value AS FLOAT) FROM {database}.classification_metrics WHERE metric_name = 'Accuracy') >= 0.9 THEN 'Excellent'
        WHEN (SELECT CAST(metric_value AS FLOAT) FROM {database}.classification_metrics WHERE metric_name = 'Accuracy') >= 0.8 THEN 'Good'
        WHEN (SELECT CAST(metric_value AS FLOAT) FROM {database}.classification_metrics WHERE metric_name = 'Accuracy') >= 0.7 THEN 'Moderate'
        ELSE 'Needs Improvement'
    END as overall_assessment;

-- =====================================================
