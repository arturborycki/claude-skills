-- Parameter Optimization for TD_SMOOTHING
-- Grid search for smoothing parameter tuning
-- Focus: Smoothing methods, window sizes, bandwidth parameters

-- INSTRUCTIONS:
-- 1. Run uaf_data_preparation.sql first to prepare signal data
-- 2. Configure smoothing parameter grids
-- 3. Evaluate smoothing quality vs detail preservation
-- 4. Select optimal smoothing configuration

-- ============================================================================
-- STEP 1: Smoothing Parameter Grid
-- ============================================================================

DROP TABLE IF EXISTS smoothing_param_grid;
CREATE MULTISET TABLE smoothing_param_grid (
    smooth_config_id INTEGER,
    smoothing_method VARCHAR(50),
    window_size INTEGER,
    bandwidth DECIMAL(8,4),
    polynomial_order INTEGER,
    weight_function VARCHAR(50)
);

INSERT INTO smoothing_param_grid VALUES
    -- Simple Moving Average
    (1, 'simple_ma', 3, NULL, NULL, 'uniform'),
    (2, 'simple_ma', 5, NULL, NULL, 'uniform'),
    (3, 'simple_ma', 7, NULL, NULL, 'uniform'),
    (4, 'simple_ma', 10, NULL, NULL, 'uniform'),
    (5, 'simple_ma', 15, NULL, NULL, 'uniform'),
    (6, 'simple_ma', 20, NULL, NULL, 'uniform'),

    -- Weighted Moving Average
    (7, 'weighted_ma', 5, NULL, NULL, 'triangular'),
    (8, 'weighted_ma', 7, NULL, NULL, 'triangular'),
    (9, 'weighted_ma', 10, NULL, NULL, 'gaussian'),
    (10, 'weighted_ma', 15, NULL, NULL, 'gaussian'),

    -- Exponential Smoothing
    (11, 'exponential', NULL, 0.1, NULL, 'exponential'),
    (12, 'exponential', NULL, 0.2, NULL, 'exponential'),
    (13, 'exponential', NULL, 0.3, NULL, 'exponential'),
    (14, 'exponential', NULL, 0.5, NULL, 'exponential'),

    -- Savitzky-Golay Filter
    (15, 'savitzky_golay', 5, NULL, 2, 'polynomial'),
    (16, 'savitzky_golay', 7, NULL, 2, 'polynomial'),
    (17, 'savitzky_golay', 9, NULL, 2, 'polynomial'),
    (18, 'savitzky_golay', 7, NULL, 3, 'polynomial'),

    -- Gaussian Smoothing
    (19, 'gaussian', 5, 1.0, NULL, 'gaussian'),
    (20, 'gaussian', 7, 1.5, NULL, 'gaussian'),
    (21, 'gaussian', 10, 2.0, NULL, 'gaussian'),

    -- Median Filter (robust to outliers)
    (22, 'median', 3, NULL, NULL, 'uniform'),
    (23, 'median', 5, NULL, NULL, 'uniform'),
    (24, 'median', 7, NULL, NULL, 'uniform'),

    -- LOWESS (Locally Weighted Scatterplot Smoothing)
    (25, 'lowess', 10, 0.1, 1, 'tricube'),
    (26, 'lowess', 15, 0.2, 1, 'tricube'),
    (27, 'lowess', 20, 0.3, 2, 'tricube');

-- ============================================================================
-- STEP 2: Smoothing Quality Metrics Template
-- ============================================================================

DROP TABLE IF EXISTS smoothing_optimization_results;
CREATE MULTISET TABLE smoothing_optimization_results (
    smooth_config_id INTEGER,
    smoothing_method VARCHAR(50),
    window_size INTEGER,
    bandwidth DECIMAL(8,4),
    -- Smoothness metrics
    roughness_reduction DECIMAL(10,6),
    noise_reduction_pct DECIMAL(10,4),
    smoothness_score DECIMAL(10,6),
    -- Detail preservation metrics
    peak_preservation DECIMAL(10,6),
    trend_preservation DECIMAL(10,6),
    feature_retention DECIMAL(10,6),
    -- Trade-off metrics
    mse_original DECIMAL(18,8),
    snr_improvement DECIMAL(10,4),
    -- Overall quality
    smoothing_quality_score DECIMAL(10,6),
    created_timestamp TIMESTAMP
);

-- ============================================================================
-- STEP 3: Calculate Smoothing Quality for Each Configuration
-- ============================================================================

INSERT INTO smoothing_optimization_results
SELECT
    p.smooth_config_id,
    p.smoothing_method,
    p.window_size,
    p.bandwidth,
    -- Simulated smoothing metrics (replace with actual TD_SMOOTHING results)
    -- Roughness reduction (higher is smoother)
    0.50 + (COALESCE(p.window_size, 5) * 0.02) - (RANDOM() * 0.10) as roughness_reduction,
    -- Noise reduction percentage
    30.0 + (COALESCE(p.window_size, 5) * 2.0) - (RANDOM() * 10.0) as noise_reduction_pct,
    -- Smoothness score (0-1, higher is smoother)
    0.60 + (COALESCE(p.window_size, 5) * 0.02) - (RANDOM() * 0.10) as smoothness_score,
    -- Peak preservation (0-1, higher is better)
    0.95 - (COALESCE(p.window_size, 5) * 0.02) + (RANDOM() * 0.05) as peak_preservation,
    -- Trend preservation (0-1, higher is better)
    0.90 - (COALESCE(p.window_size, 5) * 0.015) + (RANDOM() * 0.05) as trend_preservation,
    -- Feature retention (0-1, higher is better)
    0.88 - (COALESCE(p.window_size, 5) * 0.018) + (RANDOM() * 0.06) as feature_retention,
    -- MSE vs original signal
    0.010 + (COALESCE(p.window_size, 5) * 0.001) + (RANDOM() * 0.005) as mse_original,
    -- SNR improvement (dB)
    5.0 + (COALESCE(p.window_size, 5) * 0.5) - (RANDOM() * 2.0) as snr_improvement,
    -- Overall quality (calculated below)
    0.0 as smoothing_quality_score,
    CURRENT_TIMESTAMP
FROM smoothing_param_grid p;

-- Update overall quality score
UPDATE smoothing_optimization_results
SET smoothing_quality_score = (
    smoothness_score * 0.30 +
    (noise_reduction_pct / 100.0) * 0.25 +
    peak_preservation * 0.20 +
    trend_preservation * 0.15 +
    feature_retention * 0.10
);

-- ============================================================================
-- STEP 4: Smoothing Method Comparison
-- ============================================================================

SELECT
    'Smoothing Method Comparison' as AnalysisType,
    smoothing_method,
    COUNT(*) as ConfigCount,
    AVG(smoothness_score) as AvgSmoothness,
    AVG(peak_preservation) as AvgPeakPreservation,
    AVG(noise_reduction_pct) as AvgNoiseReduction,
    AVG(mse_original) as AvgMSE,
    AVG(smoothing_quality_score) as AvgQualityScore
FROM smoothing_optimization_results
GROUP BY smoothing_method
ORDER BY AvgQualityScore DESC;

-- ============================================================================
-- STEP 5: Window Size Impact Analysis
-- ============================================================================

SELECT
    'Window Size Impact' as AnalysisType,
    window_size,
    AVG(smoothness_score) as AvgSmoothness,
    AVG(peak_preservation) as AvgPeakPreservation,
    AVG(trend_preservation) as AvgTrendPreservation,
    AVG(feature_retention) as AvgFeatureRetention,
    -- Trade-off indicator
    AVG(smoothness_score - peak_preservation) as SmoothVsDetailTradeoff
FROM smoothing_optimization_results
WHERE window_size IS NOT NULL
GROUP BY window_size
ORDER BY window_size;

-- ============================================================================
-- STEP 6: Bandwidth Parameter Analysis (for Gaussian/LOWESS)
-- ============================================================================

SELECT
    'Bandwidth Parameter Analysis' as AnalysisType,
    smoothing_method,
    bandwidth,
    AVG(smoothness_score) as AvgSmoothness,
    AVG(noise_reduction_pct) as AvgNoiseReduction,
    AVG(snr_improvement) as AvgSNR_Improvement,
    AVG(smoothing_quality_score) as AvgQualityScore
FROM smoothing_optimization_results
WHERE bandwidth IS NOT NULL
GROUP BY smoothing_method, bandwidth
ORDER BY smoothing_method, bandwidth;

-- ============================================================================
-- STEP 7: Smoothness vs Detail Preservation Trade-off
-- ============================================================================

SELECT
    'Trade-off Analysis' as AnalysisType,
    smooth_config_id,
    smoothing_method,
    window_size,
    CAST(smoothness_score AS DECIMAL(6,4)) as Smoothness,
    CAST(peak_preservation AS DECIMAL(6,4)) as PeakPreservation,
    CAST(feature_retention AS DECIMAL(6,4)) as FeatureRetention,
    CAST(mse_original AS DECIMAL(10,6)) as MSE,
    CASE
        WHEN smoothness_score > 0.80 AND peak_preservation > 0.85 THEN 'Excellent Balance'
        WHEN smoothness_score > 0.70 AND peak_preservation > 0.75 THEN 'Good Balance'
        WHEN smoothness_score > 0.80 AND peak_preservation < 0.70 THEN 'Over-smoothed'
        WHEN smoothness_score < 0.60 AND peak_preservation > 0.90 THEN 'Under-smoothed'
        ELSE 'Moderate Balance'
    END as TradeoffAssessment
FROM smoothing_optimization_results
ORDER BY smoothing_quality_score DESC;

-- ============================================================================
-- STEP 8: Noise Reduction Effectiveness
-- ============================================================================

SELECT
    'Noise Reduction Effectiveness' as AnalysisType,
    smoothing_method,
    AVG(noise_reduction_pct) as AvgNoiseReduction,
    AVG(snr_improvement) as AvgSNR_ImprovementDB,
    AVG(smoothness_score) as AvgSmoothness,
    AVG(mse_original) as AvgMSE,
    CASE
        WHEN AVG(noise_reduction_pct) > 50 THEN 'High Noise Reduction'
        WHEN AVG(noise_reduction_pct) > 30 THEN 'Moderate Noise Reduction'
        ELSE 'Low Noise Reduction'
    END as NoiseReductionCapability
FROM smoothing_optimization_results
GROUP BY smoothing_method
ORDER BY AvgNoiseReduction DESC;

-- ============================================================================
-- STEP 9: Optimal Smoothing Configuration Selection
-- ============================================================================

-- Rank all configurations
SELECT
    'Top Smoothing Configurations' as ReportType,
    smooth_config_id,
    smoothing_method,
    window_size,
    bandwidth,
    CAST(smoothing_quality_score AS DECIMAL(6,4)) as QualityScore,
    CAST(smoothness_score AS DECIMAL(6,4)) as Smoothness,
    CAST(peak_preservation AS DECIMAL(6,4)) as PeakPreservation,
    CAST(noise_reduction_pct AS DECIMAL(6,2)) as NoiseReductionPct,
    RANK() OVER (ORDER BY smoothing_quality_score DESC) as Rank
FROM smoothing_optimization_results
ORDER BY smoothing_quality_score DESC
FETCH FIRST 10 ROWS ONLY;

-- Best configuration overall
SELECT
    'OPTIMAL SMOOTHING CONFIGURATION' as ConfigType,
    smoothing_method as RecommendedMethod,
    window_size as RecommendedWindowSize,
    bandwidth as RecommendedBandwidth,
    polynomial_order as RecommendedPolynomialOrder,
    CAST(smoothing_quality_score AS DECIMAL(6,4)) as QualityScore,
    CAST(smoothness_score AS DECIMAL(6,4)) as Smoothness,
    CAST(peak_preservation AS DECIMAL(6,4)) as PeakPreservation,
    CAST(noise_reduction_pct AS DECIMAL(6,2)) as NoiseReductionPct
FROM smoothing_optimization_results r
INNER JOIN smoothing_param_grid p ON r.smooth_config_id = p.smooth_config_id
ORDER BY smoothing_quality_score DESC
FETCH FIRST 1 ROW ONLY;

-- Best for high noise scenarios
SELECT
    'BEST FOR HIGH NOISE' as ConfigType,
    smoothing_method,
    window_size,
    bandwidth,
    CAST(noise_reduction_pct AS DECIMAL(6,2)) as NoiseReductionPct,
    CAST(smoothing_quality_score AS DECIMAL(6,4)) as QualityScore
FROM smoothing_optimization_results
ORDER BY noise_reduction_pct DESC
FETCH FIRST 1 ROW ONLY;

-- Best for detail preservation
SELECT
    'BEST FOR DETAIL PRESERVATION' as ConfigType,
    smoothing_method,
    window_size,
    bandwidth,
    CAST(peak_preservation AS DECIMAL(6,4)) as PeakPreservation,
    CAST(feature_retention AS DECIMAL(6,4)) as FeatureRetention,
    CAST(smoothing_quality_score AS DECIMAL(6,4)) as QualityScore
FROM smoothing_optimization_results
WHERE smoothness_score > 0.60  -- Minimum smoothness threshold
ORDER BY peak_preservation DESC
FETCH FIRST 1 ROW ONLY;

-- Export optimal configuration
DROP TABLE IF EXISTS optimal_smoothing_config;
CREATE MULTISET TABLE optimal_smoothing_config AS (
    SELECT
        r.*,
        p.polynomial_order,
        p.weight_function,
        'PRODUCTION' as config_status,
        CURRENT_TIMESTAMP as config_timestamp
    FROM smoothing_optimization_results r
    INNER JOIN smoothing_param_grid p ON r.smooth_config_id = p.smooth_config_id
    ORDER BY r.smoothing_quality_score DESC
    FETCH FIRST 1 ROW ONLY
) WITH DATA;

SELECT * FROM optimal_smoothing_config;

/*
SMOOTHING PARAMETER OPTIMIZATION CHECKLIST:
□ Test multiple smoothing methods
□ Evaluate various window sizes (3, 5, 7, 10, 15, 20)
□ Configure bandwidth parameters for Gaussian/LOWESS
□ Assess smoothness vs detail preservation trade-off
□ Measure noise reduction effectiveness
□ Evaluate peak and feature preservation
□ Calculate SNR improvement
□ Select optimal configuration based on use case

SMOOTHING METHOD CHARACTERISTICS:
1. Simple MA: Fast, easy, but may blur sharp features
2. Weighted MA: Better edge preservation than simple MA
3. Exponential: Good for recent data emphasis, fast
4. Savitzky-Golay: Excellent peak/feature preservation
5. Gaussian: Smooth gradual transitions, good for normal noise
6. Median: Robust to outliers, preserves edges
7. LOWESS: Adaptive, excellent for non-uniform noise

QUALITY SCORE WEIGHTS:
- Smoothness: 30% (noise reduction)
- Noise Reduction: 25% (signal quality)
- Peak Preservation: 20% (feature retention)
- Trend Preservation: 15% (overall pattern)
- Feature Retention: 10% (detail preservation)

USE CASE RECOMMENDATIONS:
- High Noise: Large window, median or LOWESS
- Preserve Peaks: Savitzky-Golay or median
- Fast Computation: Simple MA or exponential
- Adaptive: LOWESS or Gaussian
- General Purpose: Weighted MA or Savitzky-Golay

NEXT STEPS:
1. Review optimal configuration for your signal type
2. Validate smoothing quality visually
3. Check that important features are preserved
4. Apply optimal configuration to production
5. Monitor smoothing performance
6. Use optimal_smoothing_config in td_smoothing_workflow.sql
*/
