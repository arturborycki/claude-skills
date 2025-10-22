-- =====================================================
-- Hierarchical Clustering - Clustering Evaluation
-- =====================================================
-- Purpose: Evaluate clustering quality
-- Metrics: Within-cluster sum of squares, silhouette score
-- =====================================================

-- Step 1: Cluster size distribution
SELECT
    cluster_id,
    COUNT(*) as cluster_size,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {database}.hclust_model_out
WHERE result_type = 'assignment'
GROUP BY cluster_id
ORDER BY cluster_id;

-- Step 2: Within-cluster variance
SELECT
    'Within-Cluster Sum of Squares' as metric,
    SUM(distance_to_centroid) as wcss
FROM {database}.hclust_model_out
WHERE result_type = 'assignment';

-- Step 3: Cluster balance check
WITH cluster_sizes AS (
    SELECT
        cluster_id,
        COUNT(*) as size
    FROM {database}.hclust_model_out
    WHERE result_type = 'assignment'
    GROUP BY cluster_id
)
SELECT
    MAX(size) * 1.0 / NULLIF(MIN(size), 0) as imbalance_ratio,
    CASE
        WHEN MAX(size) * 1.0 / NULLIF(MIN(size), 0) <= 3 THEN 'Balanced'
        WHEN MAX(size) * 1.0 / NULLIF(MIN(size), 0) <= 10 THEN 'Moderate Imbalance'
        ELSE 'Severe Imbalance'
    END as balance_status
FROM cluster_sizes;

-- Step 4: Cluster centroids distance matrix
WITH centroids AS (
    SELECT
        cluster_id,
        {feature_columns}
    FROM {database}.hclust_model_out
    WHERE result_type = 'centroid'
)
SELECT
    c1.cluster_id as cluster1,
    c2.cluster_id as cluster2,
    SQRT(POWER(c1.{feature1} - c2.{feature1}, 2) +
         POWER(c1.{feature2} - c2.{feature2}, 2)) as distance
FROM centroids c1
CROSS JOIN centroids c2
WHERE c1.cluster_id < c2.cluster_id
ORDER BY distance;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- Evaluation criteria:
-- - Lower WCSS indicates tighter clusters
-- - Balanced cluster sizes preferred
-- - Well-separated centroids indicate distinct clusters
-- Use elbow method to determine optimal k
-- =====================================================
