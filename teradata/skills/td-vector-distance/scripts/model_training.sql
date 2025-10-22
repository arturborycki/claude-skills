-- =====================================================
-- TD_VectorDistance - No Training Required
-- =====================================================
-- TD_VectorDistance is a distance calculation function
-- No model training is required

-- Verify input vectors are ready
SELECT
    'Vector Data Check' as check_type,
    COUNT(*) as n_vectors,
    COUNT(*) * (COUNT(*) - 1) / 2 as potential_pairs
FROM {database}.vector_input;

-- Calculate pairwise distances (example)
SELECT
    v1.vector_id as id1,
    v2.vector_id as id2,
    SQRT(POWER(v1.f1-v2.f1, 2) + POWER(v1.f2-v2.f2, 2)) as euclidean_dist
FROM {database}.vector_input v1
CROSS JOIN {database}.vector_input v2
WHERE v1.vector_id < v2.vector_id
ORDER BY 3
LIMIT 20;
-- =====================================================
