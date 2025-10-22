-- TD_SPECTRAL_DENSITY Parameter Optimization

DROP TABLE IF EXISTS psd_param_optimization;
CREATE MULTISET TABLE psd_param_optimization AS (
    SELECT
        'PSD Parameters' as AnalysisType,
        sample_count,
        CASE
            WHEN sample_count > 1024 THEN 512
            WHEN sample_count > 512 THEN 256
            ELSE 128
        END as RecommendedWindowSize,
        'Welch' as RecommendedMethod,
        'Hanning' as RecommendedWindowFunction,
        '50% (half window size)' as RecommendedOverlap
    FROM (
        SELECT COUNT(*) as sample_count FROM uaf_spectral_density_prepared
    ) t
) WITH DATA;

SELECT * FROM psd_param_optimization;

SELECT '-- Optimized TD_SPECTRAL_DENSITY Configuration'
UNION ALL SELECT 'SELECT * FROM TD_SPECTRAL_DENSITY ('
UNION ALL SELECT '    ON uaf_spectral_density_prepared'
UNION ALL SELECT '    USING'
UNION ALL SELECT '    Method (''Welch''),'
UNION ALL SELECT '    WindowSize (' || CAST(RecommendedWindowSize AS VARCHAR(10)) || '),' FROM psd_param_optimization
UNION ALL SELECT '    Overlap (' || CAST(RecommendedWindowSize/2 AS VARCHAR(10)) || '),' FROM psd_param_optimization
UNION ALL SELECT '    WindowFunction (''Hanning'')'
UNION ALL SELECT ') AS dt;';
