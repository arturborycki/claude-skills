-- =====================================================
-- K-Means - Model Training Script
-- =====================================================
-- Purpose: Perform k-means clustering
-- Input: Scaled numeric data
-- Output: Cluster assignments and centroids
-- =====================================================

-- Step 1: Verify data exists
SELECT 'Data Summary' as check_type, COUNT(*) as total_records
FROM {database}.kmeans_scaled_data;

-- Step 2: Train clustering model with k clusters
DROP TABLE IF EXISTS {database}.kmeans_model_out;
CREATE MULTISET TABLE {database}.kmeans_model_out AS (
    SELECT * FROM TD_KMeans (
        ON {database}.kmeans_scaled_data AS InputTable
        USING
        InputColumns ({scaled_feature_columns})
        NumClusters ({k_value})
        MaxIterations (100)
        StopThreshold (0.001)
        Seed (42)
    ) as dt
) WITH DATA;

-- Step 3: View cluster centroids
SELECT * FROM {database}.kmeans_model_out
WHERE result_type = 'centroid'
ORDER BY cluster_id;

-- Step 4: View cluster assignments
SELECT cluster_id, COUNT(*) as cluster_size
FROM {database}.kmeans_model_out
WHERE result_type = 'assignment'
GROUP BY cluster_id
ORDER BY cluster_size DESC;

-- Step 5: Calculate cluster statistics
SELECT
    cluster_id,
    COUNT(*) as size,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {database}.kmeans_model_out
WHERE result_type = 'assignment'
GROUP BY cluster_id
ORDER BY cluster_id;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- Parameters:
--   NumClusters: Number of clusters (k)
--   MaxIterations: Maximum iterations (default 100)
--   StopThreshold: Convergence threshold (default 0.001)
--   Seed: Random seed for reproducibility
-- Next: Proceed to evaluation.sql
-- =====================================================
