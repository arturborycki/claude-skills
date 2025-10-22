-- TD_DETREND Parameter Optimization

DROP TABLE IF EXISTS detrend_param_optimization;
CREATE MULTISET TABLE detrend_param_optimization AS (
    SELECT
        trend_type,
        CASE
            WHEN trend_type LIKE '%Polynomial%' THEN 'polynomial'
            WHEN trend_type LIKE '%Linear%' THEN 'linear'
            ELSE 'constant'
        END as RecommendedDetrendType,
        CASE
            WHEN trend_type LIKE '%Polynomial%' THEN 2
            ELSE 1
        END as RecommendedPolynomialOrder
    FROM trend_analysis
) WITH DATA;

SELECT * FROM detrend_param_optimization;

SELECT '-- Optimized TD_DETREND Configuration'
UNION ALL SELECT 'SELECT * FROM TD_DETREND ('
UNION ALL SELECT '    ON uaf_detrend_prepared'
UNION ALL SELECT '    USING'
UNION ALL SELECT '    DetrendType (''' || RecommendedDetrendType || '''),' FROM detrend_param_optimization
UNION ALL SELECT '    PolynomialOrder (' || CAST(RecommendedPolynomialOrder AS VARCHAR(5)) || ')' FROM detrend_param_optimization
UNION ALL SELECT ') AS dt;';
