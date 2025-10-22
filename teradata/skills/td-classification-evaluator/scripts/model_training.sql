-- =====================================================
-- TD_ClassificationEvaluator - Model Training Script
-- =====================================================
-- Purpose: TD_ClassificationEvaluator is for EVALUATION ONLY
-- Function: TD_ClassificationEvaluator
-- Note: NO MODEL TRAINING occurs with this function
-- =====================================================

-- IMPORTANT: TD_ClassificationEvaluator does NOT train models
-- It evaluates predictions from already-trained classification models

-- TD_ClassificationEvaluator requires:
-- - Actual class labels (ground truth)
-- - Predicted class labels (from your trained model)
-- - Optional: Predicted probabilities

-- Predictions should come from trained models such as:
-- 1. TD_LogisticRegression / TD_GLM
-- 2. TD_DecisionForest / TD_RandomForest  
-- 3. TD_NaiveBayes
-- 4. TD_SVM
-- 5. TD_NeuralNet (classification)

-- Verify prepared data
SELECT
    'Data Preparation Check' as check_type,
    COUNT(*) as total_records,
    COUNT(DISTINCT actual_label) as n_classes_actual,
    COUNT(DISTINCT predicted_label) as n_classes_predicted,
    CASE
        WHEN COUNT(*) > 0 AND COUNT(DISTINCT actual_label) >= 2
        THEN 'READY FOR EVALUATION'
        ELSE 'RUN PREPROCESSING FIRST'
    END as status
FROM {database}.classification_evaluation_input;

-- Manual accuracy calculation
SELECT
    'Manual Accuracy Calculation' as metric_source,
    COUNT(*) as n_observations,
    SUM(CASE WHEN actual_label = predicted_label THEN 1 ELSE 0 END) as correct,
    SUM(CASE WHEN actual_label <> predicted_label THEN 1 ELSE 0 END) as incorrect,
    CAST(SUM(CASE WHEN actual_label = predicted_label THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as accuracy_pct
FROM {database}.classification_evaluation_input;

-- Baseline model comparison (majority class)
WITH majority_class AS (
    SELECT TOP 1 actual_label as majority_label, COUNT(*) as count
    FROM {database}.classification_evaluation_input
    GROUP BY 1
    ORDER BY 2 DESC
)
SELECT
    'Baseline Comparison' as comparison_type,
    (SELECT CAST(SUM(CASE WHEN actual_label = predicted_label THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2))
     FROM {database}.classification_evaluation_input) as model_accuracy,
    (SELECT CAST(MAX(count) * 100.0 / SUM(count) AS DECIMAL(5,2)) 
     FROM (SELECT COUNT(*) as count FROM {database}.classification_evaluation_input GROUP BY actual_label) t) as baseline_accuracy,
    CASE
        WHEN (SELECT CAST(SUM(CASE WHEN actual_label = predicted_label THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2))
              FROM {database}.classification_evaluation_input) >
             (SELECT CAST(MAX(count) * 100.0 / SUM(count) AS DECIMAL(5,2)) 
              FROM (SELECT COUNT(*) as count FROM {database}.classification_evaluation_input GROUP BY actual_label) t)
        THEN 'Model beats baseline'
        ELSE 'Model does not beat baseline'
    END as assessment;

-- Next: Run evaluation.sql to execute TD_ClassificationEvaluator
-- =====================================================
