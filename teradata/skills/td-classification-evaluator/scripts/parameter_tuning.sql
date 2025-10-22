-- =====================================================
-- TD_ClassificationEvaluator - Model Comparison
-- =====================================================

-- Compare multiple classification models
SELECT
    'Logistic Regression' as model_name,
    SUM(CASE WHEN actual_label = pred_lr THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as accuracy
FROM {database}.{multi_model_table}

UNION ALL

SELECT
    'Random Forest' as model_name,
    SUM(CASE WHEN actual_label = pred_rf THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as accuracy
FROM {database}.{multi_model_table}

UNION ALL

SELECT
    'Naive Bayes' as model_name,
    SUM(CASE WHEN actual_label = pred_nb THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as accuracy
FROM {database}.{multi_model_table}

ORDER BY accuracy DESC;

-- Per-class F1 scores for model selection
WITH model1_metrics AS (
    SELECT actual_label as class_label,
           2.0 * SUM(CASE WHEN actual_label = pred_lr AND actual_label = '{class}' THEN 1 ELSE 0 END) /
           NULLIF(SUM(CASE WHEN actual_label = '{class}' OR pred_lr = '{class}' THEN 1 ELSE 0 END), 0) as f1
    FROM {database}.{multi_model_table}
    GROUP BY 1
)
SELECT
    class_label,
    CAST(f1 AS DECIMAL(5,4)) as f1_score
FROM model1_metrics
ORDER BY class_label;
-- =====================================================
