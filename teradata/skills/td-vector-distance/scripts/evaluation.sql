-- =====================================================
-- TD_VectorDistance - Evaluation
-- =====================================================
-- Distance distribution
SELECT
    CASE
        WHEN distance < 0.1 THEN 'Very close (<0.1)'
        WHEN distance < 0.5 THEN 'Close (0.1-0.5)'
        WHEN distance < 1.0 THEN 'Moderate (0.5-1.0)'
        WHEN distance < 2.0 THEN 'Far (1.0-2.0)'
        ELSE 'Very far (>2.0)'
    END as distance_bin,
    COUNT(*) as count
FROM {database}.vector_distances
GROUP BY 1
ORDER BY MIN(distance);

-- Average nearest neighbor distance
SELECT
    target_id,
    AVG(distance) as avg_nn_distance,
    MIN(distance) as min_distance
FROM {database}.vector_distances
GROUP BY 1
ORDER BY 2
LIMIT 20;
-- =====================================================
