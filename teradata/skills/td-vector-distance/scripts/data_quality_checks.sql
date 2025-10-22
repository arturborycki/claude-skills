-- =====================================================
-- TD_VectorDistance - Data Quality Checks
-- =====================================================
-- Check for NULL values in features
SELECT
    'NULL Feature Check' as check_name,
    SUM(CASE WHEN f1 IS NULL THEN 1 ELSE 0 END) as null_f1,
    SUM(CASE WHEN f2 IS NULL THEN 1 ELSE 0 END) as null_f2,
    SUM(CASE WHEN f3 IS NULL THEN 1 ELSE 0 END) as null_f3
FROM {database}.vector_input;

-- Check for zero vectors
SELECT
    COUNT(*) as zero_vectors
FROM {database}.vector_input
WHERE f1 = 0 AND f2 = 0 AND f3 = 0;

-- Feature statistics
SELECT
    'Feature Statistics' as stat_type,
    AVG(f1) as avg_f1,
    STDDEV(f1) as std_f1,
    MIN(f1) as min_f1,
    MAX(f1) as max_f1
FROM {database}.vector_input;
-- =====================================================
