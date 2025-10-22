-- =====================================================
-- TD_ClassificationEvaluator - Data Preprocessing
-- =====================================================
-- Purpose: Prepare evaluation data for classification model assessment
-- Function: TD_ClassificationEvaluator
-- Note: This is for EVALUATION only, not model training
-- =====================================================

-- =====================================================
-- Step 1: Verify Input Data Structure
-- =====================================================

SELECT TOP 10
    {id_column},
    {actual_label_column},
    {predicted_label_column},
    {probability_column}  -- Optional: predicted probabilities
FROM {database}.{predictions_table}
ORDER BY {id_column};

-- =====================================================
-- Step 2: Data Completeness Check
-- =====================================================

SELECT
    'Data Completeness Check' as check_type,
    COUNT(*) as total_records,
    COUNT({id_column}) as id_count,
    COUNT({actual_label_column}) as actual_count,
    COUNT({predicted_label_column}) as predicted_count,
    COUNT(*) - COUNT({actual_label_column}) as missing_actual,
    COUNT(*) - COUNT({predicted_label_column}) as missing_predicted,
    CASE
        WHEN COUNT({actual_label_column}) = COUNT(*)
         AND COUNT({predicted_label_column}) = COUNT(*)
        THEN 'READY FOR EVALUATION'
        ELSE 'MISSING VALUES DETECTED'
    END as data_status
FROM {database}.{predictions_table};

-- =====================================================
-- Step 3: Check Class Distribution
-- =====================================================

-- Actual class distribution
SELECT
    'Actual Classes' as label_type,
    {actual_label_column} as class_label,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {database}.{predictions_table}
GROUP BY 2

UNION ALL

-- Predicted class distribution
SELECT
    'Predicted Classes' as label_type,
    {predicted_label_column} as class_label,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {database}.{predictions_table}
GROUP BY 2

ORDER BY label_type, class_label;

-- =====================================================
-- Step 4: Check for Duplicate IDs
-- =====================================================

SELECT
    {id_column},
    COUNT(*) as occurrence_count
FROM {database}.{predictions_table}
GROUP BY {id_column}
HAVING COUNT(*) > 1;

-- =====================================================
-- Step 5: Create Clean Evaluation Dataset
-- =====================================================

DROP TABLE IF EXISTS {database}.classification_evaluation_input;
CREATE MULTISET TABLE {database}.classification_evaluation_input AS (
    SELECT
        {id_column},
        CAST({actual_label_column} AS VARCHAR(100)) as actual_label,
        CAST({predicted_label_column} AS VARCHAR(100)) as predicted_label
    FROM {database}.{predictions_table}
    WHERE {actual_label_column} IS NOT NULL
      AND {predicted_label_column} IS NOT NULL
      AND {id_column} IS NOT NULL
) WITH DATA;

-- =====================================================
-- Step 6: Class Balance Analysis
-- =====================================================

WITH class_counts AS (
    SELECT
        actual_label,
        COUNT(*) as count
    FROM {database}.classification_evaluation_input
    GROUP BY 1
),
class_stats AS (
    SELECT
        MIN(count) as min_count,
        MAX(count) as max_count,
        AVG(count) as avg_count
    FROM class_counts
)
SELECT
    'Class Balance Analysis' as analysis_type,
    (SELECT COUNT(DISTINCT actual_label) FROM {database}.classification_evaluation_input) as n_classes,
    CAST(min_count AS INTEGER) as min_class_size,
    CAST(max_count AS INTEGER) as max_class_size,
    CAST(avg_count AS DECIMAL(10,2)) as avg_class_size,
    CAST(max_count * 1.0 / NULLIF(min_count, 0) AS DECIMAL(10,2)) as imbalance_ratio,
    CASE
        WHEN max_count * 1.0 / NULLIF(min_count, 0) < 1.5 THEN 'Balanced'
        WHEN max_count * 1.0 / NULLIF(min_count, 0) < 3.0 THEN 'Slightly imbalanced'
        WHEN max_count * 1.0 / NULLIF(min_count, 0) < 10.0 THEN 'Moderately imbalanced'
        ELSE 'Severely imbalanced'
    END as balance_status
FROM class_stats;

-- =====================================================
-- Step 7: Quick Accuracy Check
-- =====================================================

SELECT
    'Quick Accuracy Check' as metric_type,
    COUNT(*) as total_predictions,
    SUM(CASE WHEN actual_label = predicted_label THEN 1 ELSE 0 END) as correct_predictions,
    SUM(CASE WHEN actual_label <> predicted_label THEN 1 ELSE 0 END) as incorrect_predictions,
    CAST(SUM(CASE WHEN actual_label = predicted_label THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as accuracy_pct
FROM {database}.classification_evaluation_input;

-- =====================================================
-- Step 8: Confusion Matrix Preview (2-Class Only)
-- =====================================================

-- For binary classification only
SELECT
    'Binary Confusion Matrix' as matrix_type,
    SUM(CASE WHEN actual_label = '{positive_class}' AND predicted_label = '{positive_class}' THEN 1 ELSE 0 END) as true_positives,
    SUM(CASE WHEN actual_label = '{negative_class}' AND predicted_label = '{positive_class}' THEN 1 ELSE 0 END) as false_positives,
    SUM(CASE WHEN actual_label = '{negative_class}' AND predicted_label = '{negative_class}' THEN 1 ELSE 0 END) as true_negatives,
    SUM(CASE WHEN actual_label = '{positive_class}' AND predicted_label = '{negative_class}' THEN 1 ELSE 0 END) as false_negatives
FROM {database}.classification_evaluation_input;

-- =====================================================
-- Step 9: Per-Class Prediction Counts
-- =====================================================

SELECT
    actual_label,
    predicted_label,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {database}.classification_evaluation_input
GROUP BY actual_label, predicted_label
ORDER BY actual_label, predicted_label;

-- =====================================================
-- Step 10: Final Readiness Check
-- =====================================================

SELECT
    'Preprocessing Status' as check_type,
    (SELECT COUNT(*) FROM {database}.classification_evaluation_input) as prepared_records,
    (SELECT COUNT(DISTINCT actual_label) FROM {database}.classification_evaluation_input) as n_classes,
    CASE
        WHEN (SELECT COUNT(*) FROM {database}.classification_evaluation_input) >= 30
         AND (SELECT COUNT(DISTINCT actual_label) FROM {database}.classification_evaluation_input) >= 2
         AND (SELECT COUNT(*) FROM {database}.classification_evaluation_input WHERE actual_label IS NULL OR predicted_label IS NULL) = 0
        THEN 'READY FOR TD_ClassificationEvaluator'
        ELSE 'REVIEW REQUIRED'
    END as status,
    CASE
        WHEN (SELECT COUNT(*) FROM {database}.classification_evaluation_input) < 30 THEN 'Insufficient sample size'
        WHEN (SELECT COUNT(DISTINCT actual_label) FROM {database}.classification_evaluation_input) < 2 THEN 'Need at least 2 classes'
        WHEN (SELECT COUNT(*) FROM {database}.classification_evaluation_input WHERE actual_label IS NULL OR predicted_label IS NULL) > 0 THEN 'NULL values present'
        ELSE 'All checks passed'
    END as notes;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- Replace placeholders:
--   {database} - Your database name
--   {predictions_table} - Table containing predictions and actuals
--   {id_column} - Unique identifier column
--   {actual_label_column} - Ground truth class labels
--   {predicted_label_column} - Model predictions
--   {positive_class} - Positive class label (binary only)
--   {negative_class} - Negative class label (binary only)
--
-- Data requirements:
--   - Minimum 30 observations recommended
--   - At least 2 classes
--   - No NULL values in label columns
--   - Labels should be consistent between actual and predicted
--
-- Next step: Run evaluation.sql to execute TD_ClassificationEvaluator
-- =====================================================
