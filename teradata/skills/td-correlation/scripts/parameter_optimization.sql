-- TD_CORRELATION Parameter Optimization

DROP TABLE IF EXISTS correlation_param_optimization;
CREATE MULTISET TABLE correlation_param_optimization AS (
    SELECT
        'Correlation Parameters' as AnalysisType,
        sample_count,
        ROUND(sample_count * 0.1) as RecommendedMaxLag,
        'cross' as RecommendedCorrelationType,
        'TRUE' as RecommendedNormalize,
        'Search for time delays and phase shifts' as Purpose
    FROM (
        SELECT COUNT(*) as sample_count FROM uaf_correlation_prepared
    ) t
) WITH DATA;

SELECT * FROM correlation_param_optimization;

SELECT '-- Optimized TD_CORRELATION Configuration'
UNION ALL SELECT 'SELECT * FROM TD_CORRELATION ('
UNION ALL SELECT '    ON uaf_correlation_prepared'
UNION ALL SELECT '    USING'
UNION ALL SELECT '    CorrelationType (''cross''),'
UNION ALL SELECT '    MaxLag (' || CAST(RecommendedMaxLag AS VARCHAR(10)) || '),' FROM correlation_param_optimization
UNION ALL SELECT '    Normalize (TRUE)'
UNION ALL SELECT ') AS dt;';
