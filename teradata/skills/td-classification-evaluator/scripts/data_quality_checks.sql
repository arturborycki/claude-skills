-- =====================================================
-- TD_ClassificationEvaluator - Data Quality Checks
-- =====================================================

-- Check 1: Data Completeness
SELECT
    'Completeness Check' as check_name,
    COUNT(*) as total_records,
    COUNT({actual_label_column}) as actual_non_null,
    COUNT({predicted_label_column}) as predicted_non_null,
    CASE
        WHEN COUNT({actual_label_column}) = COUNT(*) AND COUNT({predicted_label_column}) = COUNT(*)
        THEN 'PASS'
        ELSE 'FAIL - Missing values'
    END as status
FROM {database}.{predictions_table};

-- Check 2: Class Distribution
SELECT
    actual_label,
    COUNT(*) as count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {database}.classification_evaluation_input
GROUP BY 1
ORDER BY 2 DESC;

-- Check 3: Label Consistency
WITH actual_labels AS (
    SELECT DISTINCT actual_label as label FROM {database}.classification_evaluation_input
),
predicted_labels AS (
    SELECT DISTINCT predicted_label as label FROM {database}.classification_evaluation_input
)
SELECT
    'Label Consistency Check' as check_name,
    (SELECT COUNT(*) FROM actual_labels) as n_actual_classes,
    (SELECT COUNT(*) FROM predicted_labels) as n_predicted_classes,
    CASE
        WHEN (SELECT COUNT(*) FROM actual_labels) = (SELECT COUNT(*) FROM predicted_labels)
        THEN 'PASS - Same number of classes'
        ELSE 'WARNING - Different number of classes'
    END as status;

-- Check 4: Class Imbalance
WITH class_counts AS (
    SELECT MIN(cnt) as min_count, MAX(cnt) as max_count
    FROM (SELECT COUNT(*) as cnt FROM {database}.classification_evaluation_input GROUP BY actual_label) t
)
SELECT
    'Class Imbalance Check' as check_name,
    min_count,
    max_count,
    CAST(max_count * 1.0 / NULLIF(min_count, 0) AS DECIMAL(10,2)) as imbalance_ratio,
    CASE
        WHEN max_count * 1.0 / NULLIF(min_count, 0) < 3 THEN 'PASS - Balanced'
        WHEN max_count * 1.0 / NULLIF(min_count, 0) < 10 THEN 'WARNING - Imbalanced'
        ELSE 'FAIL - Severely imbalanced'
    END as status
FROM class_counts;

-- Check 5: Sample Size
SELECT
    'Sample Size Check' as check_name,
    COUNT(*) as sample_size,
    COUNT(DISTINCT actual_label) as n_classes,
    CASE
        WHEN COUNT(*) >= 30 * COUNT(DISTINCT actual_label) THEN 'PASS - Sufficient'
        ELSE 'WARNING - Small sample size'
    END as status
FROM {database}.classification_evaluation_input;
-- =====================================================
