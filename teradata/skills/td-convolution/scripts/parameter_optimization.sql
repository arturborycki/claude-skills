-- TD_CONVOLUTION Parameter Optimization

DROP TABLE IF EXISTS convolution_param_optimization;
CREATE MULTISET TABLE convolution_param_optimization AS (
    SELECT
        'Convolution Parameters' as AnalysisType,
        signal_length,
        kernel_length,
        'linear' as RecommendedConvolutionType,
        'same' as RecommendedEdgeHandling,
        'TRUE' as RecommendedNormalize,
        CASE
            WHEN signal_length > 1000 THEN 'Use frequency domain (FFT-based) convolution for speed'
            ELSE 'Direct time-domain convolution acceptable'
        END as PerformanceGuidance
    FROM (
        SELECT
            (SELECT COUNT(*) FROM uaf_convolution_prepared) as signal_length,
            (SELECT COUNT(*) FROM convolution_kernel) as kernel_length
    ) t
) WITH DATA;

SELECT * FROM convolution_param_optimization;

SELECT '-- Optimized TD_CONVOLUTION Configuration'
UNION ALL SELECT 'SELECT * FROM TD_CONVOLUTION ('
UNION ALL SELECT '    ON uaf_convolution_prepared AS signal'
UNION ALL SELECT '    ON convolution_kernel AS kernel'
UNION ALL SELECT '    USING'
UNION ALL SELECT '    ConvolutionType (''linear''),'
UNION ALL SELECT '    EdgeHandling (''same''),'
UNION ALL SELECT '    Normalize (TRUE)'
UNION ALL SELECT ') AS dt;';
