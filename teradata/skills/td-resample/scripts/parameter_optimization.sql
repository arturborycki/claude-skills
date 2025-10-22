-- TD_RESAMPLE Parameter Optimization

DROP TABLE IF EXISTS resample_param_optimization;
CREATE MULTISET TABLE resample_param_optimization AS (
    SELECT
        'Resample Parameters' as AnalysisType,
        current_rate_hz,
        2.0 as Example_ResamplingRatio_Upsample,
        0.5 as Example_ResamplingRatio_Downsample,
        'linear' as RecommendedInterpolationMethod,
        'TRUE' as RecommendedAntiAliasFilter
    FROM (
        SELECT CurrentSamplingRate_Hz as current_rate_hz FROM current_sampling_rate
    ) t
) WITH DATA;

SELECT * FROM resample_param_optimization;

SELECT '-- Optimized TD_RESAMPLE Configuration'
UNION ALL SELECT 'SELECT * FROM TD_RESAMPLE ('
UNION ALL SELECT '    ON uaf_resample_prepared'
UNION ALL SELECT '    USING'
UNION ALL SELECT '    ResamplingRatio (2.0),  -- Adjust as needed'
UNION ALL SELECT '    InterpolationMethod (''linear''),'
UNION ALL SELECT '    AntiAliasFilter (TRUE)'
UNION ALL SELECT ') AS dt;';
