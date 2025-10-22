-- =====================================================
-- TD_VectorDistance - Diagnostic Queries
-- =====================================================
-- Closest pairs
SELECT TOP 20
    target_id,
    ref_id,
    distance
FROM {database}.vector_distances
WHERE target_id <> ref_id
ORDER BY distance;

-- Most isolated vectors (furthest from all others)
SELECT
    target_id,
    AVG(distance) as avg_distance_to_others,
    MIN(distance) as min_distance
FROM {database}.vector_distances
WHERE target_id <> ref_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;

-- Distance statistics
SELECT
    'Distance Statistics' as analysis_type,
    COUNT(*) as n_pairs,
    MIN(distance) as min_distance,
    MAX(distance) as max_distance,
    AVG(distance) as avg_distance,
    STDDEV(distance) as std_distance
FROM {database}.vector_distances
WHERE target_id <> ref_id;

-- Neighborhood density (how many neighbors within threshold)
SELECT
    target_id,
    SUM(CASE WHEN distance < 0.5 THEN 1 ELSE 0 END) as neighbors_within_05,
    SUM(CASE WHEN distance < 1.0 THEN 1 ELSE 0 END) as neighbors_within_10
FROM {database}.vector_distances
WHERE target_id <> ref_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;
-- =====================================================
