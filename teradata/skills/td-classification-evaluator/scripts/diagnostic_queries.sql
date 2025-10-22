-- =====================================================
-- TD_ClassificationEvaluator - Diagnostic Queries
-- =====================================================

-- View all metrics
SELECT * FROM {database}.classification_metrics
ORDER BY class_label, metric_name;

-- Confusion matrix visualization
SELECT
    actual_label,
    predicted_label,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY actual_label) AS DECIMAL(5,2)) as pct_of_actual
FROM {database}.classification_evaluation_input
GROUP BY 1, 2
ORDER BY 1, 2;

-- Per-class performance
SELECT
    actual_label as class,
    SUM(CASE WHEN actual_label = predicted_label THEN 1 ELSE 0 END) as correct,
    COUNT(*) as total,
    CAST(SUM(CASE WHEN actual_label = predicted_label THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as class_accuracy
FROM {database}.classification_evaluation_input
GROUP BY 1
ORDER BY 4 DESC;

-- Most confused pairs
SELECT TOP 10
    actual_label as true_class,
    predicted_label as predicted_class,
    COUNT(*) as misclassifications,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as pct_of_errors
FROM {database}.classification_evaluation_input
WHERE actual_label <> predicted_label
GROUP BY 1, 2
ORDER BY 3 DESC;

-- Overall metrics summary
SELECT
    COUNT(*) as total_predictions,
    COUNT(DISTINCT actual_label) as n_classes,
    SUM(CASE WHEN actual_label = predicted_label THEN 1 ELSE 0 END) as correct,
    CAST(SUM(CASE WHEN actual_label = predicted_label THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as accuracy,
    CASE
        WHEN SUM(CASE WHEN actual_label = predicted_label THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 90 THEN 'Excellent'
        WHEN SUM(CASE WHEN actual_label = predicted_label THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 80 THEN 'Good'
        WHEN SUM(CASE WHEN actual_label = predicted_label THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 70 THEN 'Moderate'
        ELSE 'Poor'
    END as assessment
FROM {database}.classification_evaluation_input;
-- =====================================================
