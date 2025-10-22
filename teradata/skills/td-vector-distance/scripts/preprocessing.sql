-- =====================================================
-- TD_VectorDistance - Vector Data Preprocessing
-- =====================================================
DROP TABLE IF EXISTS {database}.vector_input;
CREATE MULTISET TABLE {database}.vector_input AS (
    SELECT
        {id_column} as vector_id,
        {feature1} as f1,
        {feature2} as f2,
        {feature3} as f3
        -- Add more features as needed
    FROM {database}.{source_table}
    WHERE {feature1} IS NOT NULL
) WITH DATA;

-- Normalize vectors (optional)
WITH vector_norms AS (
    SELECT
        vector_id,
        SQRT(f1*f1 + f2*f2 + f3*f3) as norm
    FROM {database}.vector_input
)
SELECT
    v.vector_id,
    v.f1 / n.norm as f1_normalized,
    v.f2 / n.norm as f2_normalized,
    v.f3 / n.norm as f3_normalized
FROM {database}.vector_input v
JOIN vector_norms n ON v.vector_id = n.vector_id;

-- Vector statistics
SELECT
    COUNT(*) as n_vectors,
    AVG(f1) as avg_f1,
    STDDEV(f1) as std_f1
FROM {database}.vector_input;
-- =====================================================
