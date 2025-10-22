-- =====================================================
-- TD_DecisionForestPredict - Prediction Script
-- =====================================================
-- Purpose: Generate predictions using trained decision forest model
-- Input: Trained model table and test data
-- Output: Class predictions with confidence scores
-- =====================================================

-- Step 1: Verify model and test data exist
SELECT 'Model exists' as check_type, COUNT(*) as node_count
FROM {database}.df_model_out;

SELECT 'Test data exists' as check_type, COUNT(*) as record_count
FROM {database}.df_train_test_split
WHERE train_flag = 0;

-- Step 2: Generate predictions on test set
DROP TABLE IF EXISTS {database}.df_predictions_out;
CREATE MULTISET TABLE {database}.df_predictions_out AS (
    SELECT * FROM TD_DecisionForestPredict (
        ON (SELECT * FROM {database}.df_train_test_split WHERE train_flag = 0) AS InputTable
        ON {database}.df_model_out AS ModelTable DIMENSION
        USING
        IDColumn ('{id_column}')
        Accumulate ('{id_column}', '{target_column}')
    ) as dt
) WITH DATA;

-- Step 3: View sample predictions
SELECT TOP 100
    {id_column},
    {target_column} as actual_class,
    prediction as predicted_class,
    confidence as prediction_confidence,
    CASE
        WHEN {target_column} = prediction THEN 'Correct'
        ELSE 'Incorrect'
    END as prediction_result
FROM {database}.df_predictions_out
ORDER BY confidence DESC;

-- Step 4: Calculate prediction accuracy
SELECT
    COUNT(*) as total_predictions,
    SUM(CASE WHEN {target_column} = prediction THEN 1 ELSE 0 END) as correct_predictions,
    SUM(CASE WHEN {target_column} <> prediction THEN 1 ELSE 0 END) as incorrect_predictions,
    CAST(SUM(CASE WHEN {target_column} = prediction THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as accuracy_pct
FROM {database}.df_predictions_out;

-- Step 5: Analyze predictions by class
SELECT
    {target_column} as actual_class,
    COUNT(*) as total_count,
    SUM(CASE WHEN {target_column} = prediction THEN 1 ELSE 0 END) as correct_count,
    CAST(SUM(CASE WHEN {target_column} = prediction THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as class_accuracy,
    AVG(confidence) as avg_confidence,
    MIN(confidence) as min_confidence,
    MAX(confidence) as max_confidence
FROM {database}.df_predictions_out
GROUP BY {target_column}
ORDER BY total_count DESC;

-- Step 6: Analyze predictions by predicted class
SELECT
    prediction as predicted_class,
    COUNT(*) as prediction_count,
    AVG(confidence) as avg_confidence,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as prediction_distribution_pct
FROM {database}.df_predictions_out
GROUP BY prediction
ORDER BY prediction_count DESC;

-- Step 7: Analyze prediction confidence distribution
SELECT
    CASE
        WHEN confidence >= 0.9 THEN '0.90-1.00 (Very High)'
        WHEN confidence >= 0.8 THEN '0.80-0.90 (High)'
        WHEN confidence >= 0.7 THEN '0.70-0.80 (Medium-High)'
        WHEN confidence >= 0.6 THEN '0.60-0.70 (Medium)'
        WHEN confidence >= 0.5 THEN '0.50-0.60 (Medium-Low)'
        ELSE '0.00-0.50 (Low)'
    END as confidence_range,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage,
    AVG(CASE WHEN {target_column} = prediction THEN 1.0 ELSE 0.0 END) as accuracy_in_range
FROM {database}.df_predictions_out
GROUP BY 1
ORDER BY
    CASE
        WHEN confidence >= 0.9 THEN 1
        WHEN confidence >= 0.8 THEN 2
        WHEN confidence >= 0.7 THEN 3
        WHEN confidence >= 0.6 THEN 4
        WHEN confidence >= 0.5 THEN 5
        ELSE 6
    END;

-- Step 8: Identify low-confidence predictions
SELECT
    {id_column},
    {target_column} as actual_class,
    prediction as predicted_class,
    confidence,
    CASE WHEN {target_column} = prediction THEN 'Correct' ELSE 'Incorrect' END as result
FROM {database}.df_predictions_out
WHERE confidence < 0.6
ORDER BY confidence ASC;

-- Step 9: Identify misclassifications with high confidence
SELECT
    {id_column},
    {target_column} as actual_class,
    prediction as predicted_class,
    confidence,
    'High-confidence error' as issue_type
FROM {database}.df_predictions_out
WHERE {target_column} <> prediction
  AND confidence >= 0.8
ORDER BY confidence DESC;

-- Step 10: Class confusion patterns
SELECT
    {target_column} as actual_class,
    prediction as predicted_class,
    COUNT(*) as confusion_count,
    AVG(confidence) as avg_confidence,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY {target_column}) AS DECIMAL(5,2)) as pct_of_actual
FROM {database}.df_predictions_out
GROUP BY {target_column}, prediction
ORDER BY actual_class, confusion_count DESC;

-- =====================================================
-- Prediction Summary Report
-- =====================================================

SELECT
    'Decision Forest Predictions Complete' as status,
    (SELECT COUNT(*) FROM {database}.df_predictions_out) as total_predictions,
    (SELECT CAST(AVG(CASE WHEN {target_column} = prediction THEN 100.0 ELSE 0.0 END) AS DECIMAL(5,2))
     FROM {database}.df_predictions_out) as overall_accuracy,
    (SELECT AVG(confidence) FROM {database}.df_predictions_out) as avg_confidence,
    (SELECT COUNT(*) FROM {database}.df_predictions_out WHERE confidence < 0.6) as low_confidence_count,
    (SELECT COUNT(*) FROM {database}.df_predictions_out WHERE {target_column} <> prediction) as misclassification_count;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders:
--    {database} - Your database name
--    {id_column} - Unique identifier column
--    {target_column} - Target classification variable
--
-- 2. Prerequisites:
--    - Trained model table (df_model_out) must exist
--    - Test data must have same features as training data
--    - Features must be preprocessed identically to training
--
-- 3. Output interpretation:
--    - prediction: Predicted class label
--    - confidence: Probability of predicted class (0-1)
--    - Higher confidence indicates more certain predictions
--    - Misclassifications with high confidence warrant investigation
--
-- 4. Next steps:
--    - Review prediction accuracy by class
--    - Analyze confusion patterns
--    - Proceed to evaluation.sql for detailed metrics
--
-- =====================================================
