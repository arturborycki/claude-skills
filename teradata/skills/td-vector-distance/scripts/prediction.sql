-- =====================================================
-- TD_VectorDistance - Calculate Distances
-- =====================================================
DROP TABLE IF EXISTS {database}.vector_distances;
CREATE MULTISET TABLE {database}.vector_distances AS (
    SELECT * FROM TD_VectorDistance (
        ON {database}.vector_input AS TargetTable
        ON {database}.vector_input AS RefTable
        USING
        TargetIDColumn ('vector_id')
        TargetFeatureColumns ('f1', 'f2', 'f3')
        RefIDColumn ('vector_id')
        RefFeatureColumns ('f1', 'f2', 'f3')
        DistanceMeasure ('euclidean')  -- Options: euclidean, manhattan, cosine
        TopK (10)  -- Return top 10 nearest neighbors
    ) as dt
) WITH DATA;

SELECT * FROM {database}.vector_distances
ORDER BY target_id, distance
LIMIT 100;

-- Find nearest neighbors for specific vector
SELECT
    target_id,
    ref_id as nearest_neighbor,
    distance
FROM {database}.vector_distances
WHERE target_id = '{specific_id}'
ORDER BY distance
LIMIT 10;
-- =====================================================
