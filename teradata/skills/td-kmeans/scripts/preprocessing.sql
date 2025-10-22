-- =====================================================
-- Data Preprocessing for TD_KMeans
-- =====================================================
-- Purpose: Prepare data for k-means clustering
-- Operations: Scaling, validation, feature selection
-- Note: K-means requires numeric features and benefits from scaling
-- =====================================================

-- =====================================================
-- 1. DATA QUALITY VALIDATION
-- =====================================================

SELECT
    COUNT(*) as total_records,
    COUNT(DISTINCT {id_column}) as unique_ids,
    CAST((COUNT(*) - COUNT(DISTINCT {id_column})) AS DECIMAL(10,0)) as duplicate_count
FROM {database}.{table_name};

-- Check numeric features completeness
SELECT
    '{numeric_feature_1}' as feature_name,
    COUNT(*) as total_count,
    COUNT({numeric_feature_1}) as non_null_count,
    CAST((COUNT(*) - COUNT({numeric_feature_1})) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as null_pct
FROM {database}.{table_name};

-- =====================================================
-- 2. FEATURE SCALING (REQUIRED for K-Means)
-- =====================================================

-- K-means is sensitive to scale, so normalization is essential
-- Option 1: Use TD_ScaleFit and TD_ScaleTransform
-- Option 2: Manual standardization (shown here)

DROP TABLE IF EXISTS {database}.kmeans_scaled_data;
CREATE MULTISET TABLE {database}.kmeans_scaled_data AS (
    SELECT
        {id_column},
        -- Standardize numeric features: (x - mean) / stddev
        ({numeric_feature_1} - AVG({numeric_feature_1}) OVER()) / NULLIF(STDDEV({numeric_feature_1}) OVER(), 0) as {numeric_feature_1}_scaled,
        ({numeric_feature_2} - AVG({numeric_feature_2}) OVER()) / NULLIF(STDDEV({numeric_feature_2}) OVER(), 0) as {numeric_feature_2}_scaled,
        -- Keep original features for reference
        {numeric_feature_1},
        {numeric_feature_2}
    FROM {database}.{table_name}
    WHERE {numeric_feature_1} IS NOT NULL
      AND {numeric_feature_2} IS NOT NULL
) WITH DATA;

-- Verify scaling
SELECT
    'Scaled Features' as check_type,
    AVG({numeric_feature_1}_scaled) as mean_feature1_scaled,
    STDDEV({numeric_feature_1}_scaled) as std_feature1_scaled,
    AVG({numeric_feature_2}_scaled) as mean_feature2_scaled,
    STDDEV({numeric_feature_2}_scaled) as std_feature2_scaled
FROM {database}.kmeans_scaled_data;

-- =====================================================
-- 3. FEATURE CORRELATION ANALYSIS
-- =====================================================

-- Check correlation between features (helps assess clustering potential)
SELECT
    'Feature Correlation' as metric,
    CORR({numeric_feature_1}, {numeric_feature_2}) as correlation_coefficient
FROM {database}.{table_name};

-- =====================================================
-- 4. OUTLIER DETECTION
-- =====================================================

-- Identify potential outliers (may affect clustering)
WITH stats AS (
    SELECT
        AVG({numeric_feature_1}) as mean1,
        STDDEV({numeric_feature_1}) as std1,
        AVG({numeric_feature_2}) as mean2,
        STDDEV({numeric_feature_2}) as std2
    FROM {database}.{table_name}
)
SELECT
    COUNT(*) as outlier_count,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM {database}.{table_name}) AS DECIMAL(5,2)) as outlier_pct
FROM {database}.{table_name}, stats
WHERE ABS({numeric_feature_1} - mean1) > 3 * std1
   OR ABS({numeric_feature_2} - mean2) > 3 * std2;

-- =====================================================
-- 5. SAMPLE SIZE VALIDATION
-- =====================================================

-- Check if sample size is adequate for clustering
SELECT
    COUNT(*) as total_samples,
    CASE
        WHEN COUNT(*) >= 100 THEN 'PASS - Adequate for clustering'
        WHEN COUNT(*) >= 50 THEN 'WARNING - Minimum sample size'
        ELSE 'FAIL - Insufficient samples'
    END as sample_adequacy
FROM {database}.kmeans_scaled_data;

-- =====================================================
-- 6. FINAL PREPROCESSING SUMMARY
-- =====================================================

SELECT
    'Preprocessing Complete' as status,
    COUNT(*) as total_records,
    COUNT(DISTINCT {id_column}) as unique_ids,
    'Data scaled and ready for clustering' as next_step
FROM {database}.kmeans_scaled_data;

-- =====================================================
-- Usage Notes:
-- =====================================================
-- 1. Replace placeholders with actual column names
-- 2. K-means requirements:
--    - All features must be numeric
--    - Features should be scaled (standardized or normalized)
--    - Missing values must be handled (removed or imputed)
--    - Outliers may significantly affect cluster centers
-- 3. Feature engineering tips:
--    - Select features that logically group similar records
--    - Remove highly correlated features to reduce redundancy
--    - Consider dimensionality reduction for many features
-- 4. Next steps:
--    - Determine optimal number of clusters (k)
--    - Proceed to model_training.sql
--
-- =====================================================
