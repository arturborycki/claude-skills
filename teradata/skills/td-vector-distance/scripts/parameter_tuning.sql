-- =====================================================
-- TD_VectorDistance - Parameter Tuning
-- =====================================================
-- Compare different distance measures

-- Euclidean distance
DROP TABLE IF EXISTS {database}.dist_euclidean;
CREATE MULTISET TABLE {database}.dist_euclidean AS (
    SELECT * FROM TD_VectorDistance (
        ON {database}.vector_input AS TargetTable
        ON {database}.vector_input AS RefTable
        USING
        TargetIDColumn ('vector_id')
        TargetFeatureColumns ('f1', 'f2', 'f3')
        RefIDColumn ('vector_id')
        RefFeatureColumns ('f1', 'f2', 'f3')
        DistanceMeasure ('euclidean')
        TopK (5)
    ) as dt
) WITH DATA;

-- Manhattan distance
DROP TABLE IF EXISTS {database}.dist_manhattan;
CREATE MULTISET TABLE {database}.dist_manhattan AS (
    SELECT * FROM TD_VectorDistance (
        ON {database}.vector_input AS TargetTable
        ON {database}.vector_input AS RefTable
        USING
        TargetIDColumn ('vector_id')
        TargetFeatureColumns ('f1', 'f2', 'f3')
        RefIDColumn ('vector_id')
        RefFeatureColumns ('f1', 'f2', 'f3')
        DistanceMeasure ('manhattan')
        TopK (5)
    ) as dt
) WITH DATA;

-- Compare results
SELECT
    'Euclidean' as method,
    AVG(distance) as avg_distance
FROM {database}.dist_euclidean
UNION ALL
SELECT
    'Manhattan' as method,
    AVG(distance) as avg_distance
FROM {database}.dist_manhattan;
-- =====================================================
