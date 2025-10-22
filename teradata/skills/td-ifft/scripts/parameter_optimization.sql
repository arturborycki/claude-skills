-- TD_IFFT Parameter Optimization Script
-- Analyzes frequency domain data to recommend optimal IFFT parameters
-- Teradata Unbounded Array Framework implementation

-- INSTRUCTIONS:
-- Run this after uaf_data_preparation.sql to optimize TD_IFFT parameters

-- ============================================================================
-- SECTION 1: Normalization Parameter Analysis
-- ============================================================================

DROP TABLE IF EXISTS ifft_normalization_analysis;
CREATE MULTISET TABLE ifft_normalization_analysis AS (
    SELECT
        'Normalization Recommendation' as AnalysisType,
        spectral_magnitude_sum,
        max_magnitude,
        CASE
            WHEN spectral_magnitude_sum > 1000 THEN 'TRUE'
            WHEN max_magnitude > 100 THEN 'TRUE'
            ELSE 'FALSE'
        END as RecommendedNormalize,
        CASE
            WHEN spectral_magnitude_sum > 1000 THEN 'Large spectral energy - Normalize to prevent overflow'
            WHEN max_magnitude > 100 THEN 'High peak magnitude - Normalization recommended'
            ELSE 'Moderate values - Normalization optional'
        END as Reasoning,
        expected_output_amplitude_range
    FROM (
        SELECT
            SUM(magnitude) as spectral_magnitude_sum,
            MAX(magnitude) as max_magnitude,
            SUM(magnitude) / COUNT(*) as expected_output_amplitude_range
        FROM uaf_ifft_prepared
    ) t
) WITH DATA;

SELECT * FROM ifft_normalization_analysis;

-- ============================================================================
-- SECTION 2: Output Format Selection
-- ============================================================================

DROP TABLE IF EXISTS ifft_output_format_recommendation;
CREATE MULTISET TABLE ifft_output_format_recommendation AS (
    SELECT
        'Output Format Analysis' as AnalysisType,
        hermitian_symmetric,
        complex_pairs_count,
        total_bins,
        CASE
            WHEN hermitian_symmetric > 0.95 THEN 'REAL'
            WHEN complex_pairs_count = total_bins THEN 'COMPLEX'
            ELSE 'REAL'  -- Default to real for most applications
        END as RecommendedFormat,
        CASE
            WHEN hermitian_symmetric > 0.95 THEN 'Hermitian symmetry detected - Real output expected'
            WHEN complex_pairs_count = total_bins THEN 'Full complex spectrum - Complex output possible'
            ELSE 'Default to real-valued time series'
        END as FormatReasoning
    FROM (
        SELECT
            -- Check Hermitian symmetry
            CAST(COUNT(CASE
                WHEN pos.real_part IS NOT NULL AND neg.real_part IS NOT NULL
                AND ABS(pos.real_part - neg.real_part) < 0.001
                AND ABS(pos.imag_part + neg.imag_part) < 0.001
                THEN 1 END) AS FLOAT) / NULLIFZERO(COUNT(*)) as hermitian_symmetric,
            COUNT(CASE WHEN real_part IS NOT NULL AND imag_part IS NOT NULL THEN 1 END) as complex_pairs_count,
            COUNT(*) as total_bins
        FROM uaf_ifft_prepared pos
        LEFT JOIN uaf_ifft_prepared neg
            ON pos.frequency_hz = -neg.frequency_hz
    ) t
) WITH DATA;

SELECT * FROM ifft_output_format_recommendation;

-- ============================================================================
-- SECTION 3: Signal Reconstruction Quality Prediction
-- ============================================================================

DROP TABLE IF EXISTS ifft_quality_prediction;
CREATE MULTISET TABLE ifft_quality_prediction AS (
    SELECT
        'Reconstruction Quality Estimate' as MetricType,
        frequency_coverage,
        spectral_completeness,
        dc_component_magnitude,
        nyquist_component_magnitude,
        CASE
            WHEN spectral_completeness > 0.99 THEN 'EXCELLENT: Complete spectrum'
            WHEN spectral_completeness > 0.95 THEN 'GOOD: Nearly complete spectrum'
            WHEN spectral_completeness > 0.90 THEN 'FAIR: Some missing components'
            ELSE 'POOR: Significant missing data'
        END as QualityEstimate,
        expected_snr_db
    FROM (
        SELECT
            (MAX(frequency_hz) - MIN(frequency_hz)) / NULLIFZERO(MAX(frequency_hz)) as frequency_coverage,
            CAST(COUNT(CASE WHEN magnitude > 0.001 THEN 1 END) AS FLOAT) / COUNT(*) as spectral_completeness,
            MAX(CASE WHEN frequency_hz = 0 THEN magnitude ELSE 0 END) as dc_component_magnitude,
            MAX(CASE WHEN frequency_hz = (SELECT MAX(frequency_hz) FROM uaf_ifft_prepared) THEN magnitude ELSE 0 END) as nyquist_component_magnitude,
            10 * LOG(10, MAX(magnitude) / NULLIFZERO(AVG(CASE WHEN magnitude < PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY magnitude) THEN magnitude END))) as expected_snr_db
        FROM uaf_ifft_prepared
    ) t
) WITH DATA;

SELECT * FROM ifft_quality_prediction;

-- ============================================================================
-- SECTION 4: IFFT Size Optimization
-- ============================================================================

DROP TABLE IF EXISTS ifft_size_optimization;
CREATE MULTISET TABLE ifft_size_optimization AS (
    SELECT
        'IFFT Size Recommendation' as AnalysisType,
        current_size,
        optimal_size_power2,
        padding_needed,
        output_samples,
        output_duration_sec,
        sampling_rate_hz,
        CASE
            WHEN padding_needed = 0 THEN 'OPTIMAL: No padding required'
            WHEN padding_needed < current_size * 0.1 THEN 'GOOD: Minimal padding'
            ELSE 'ACCEPTABLE: Moderate padding required'
        END as SizeAssessment
    FROM (
        SELECT
            COUNT(*) as current_size,
            POWER(2, CEILING(LOG(2, COUNT(*)))) as optimal_size_power2,
            POWER(2, CEILING(LOG(2, COUNT(*)))) - COUNT(*) as padding_needed,
            COUNT(*) as output_samples,
            COUNT(*) / (2.0 * MAX(frequency_hz)) as output_duration_sec,
            2.0 * MAX(frequency_hz) as sampling_rate_hz
        FROM uaf_ifft_prepared
        WHERE frequency_hz > 0
    ) t
) WITH DATA;

SELECT * FROM ifft_size_optimization;

-- ============================================================================
-- SECTION 5: Phase Unwrapping Analysis
-- ============================================================================

DROP TABLE IF EXISTS phase_continuity_analysis;
CREATE MULTISET TABLE phase_continuity_analysis AS (
    SELECT
        'Phase Continuity Check' as AnalysisType,
        max_phase_jump,
        avg_phase_gradient,
        phase_wrapping_detected,
        CASE
            WHEN max_phase_jump > 180 THEN 'Phase unwrapping recommended'
            WHEN max_phase_jump > 90 THEN 'Monitor phase continuity'
            ELSE 'Phase continuity acceptable'
        END as PhaseRecommendation
    FROM (
        SELECT
            MAX(ABS(phase_diff)) as max_phase_jump,
            AVG(ABS(phase_diff)) as avg_phase_gradient,
            COUNT(CASE WHEN ABS(phase_diff) > 180 THEN 1 END) as phase_wrapping_detected
        FROM (
            SELECT
                phase_degrees,
                phase_degrees - LAG(phase_degrees) OVER (ORDER BY frequency_hz) as phase_diff
            FROM uaf_ifft_prepared
            WHERE frequency_hz > 0
        ) phase_diffs
    ) t
) WITH DATA;

SELECT * FROM phase_continuity_analysis;

-- ============================================================================
-- SECTION 6: Comprehensive Parameter Recommendation
-- ============================================================================

SELECT
    'TD_IFFT PARAMETER RECOMMENDATIONS' as ReportType,
    n.RecommendedNormalize as Normalize,
    o.RecommendedFormat as OutputFormat,
    s.optimal_size_power2 as OptimalIFFTSize,
    s.output_samples as ExpectedOutputSamples,
    s.sampling_rate_hz as ReconstructedSamplingRate_Hz,
    q.QualityEstimate as ExpectedReconstructionQuality,
    p.PhaseRecommendation as PhaseHandling,
    CURRENT_TIMESTAMP as AnalysisTime
FROM ifft_normalization_analysis n
CROSS JOIN ifft_output_format_recommendation o
CROSS JOIN ifft_size_optimization s
CROSS JOIN ifft_quality_prediction q
CROSS JOIN phase_continuity_analysis p;

-- Generate SQL code snippet
SELECT '-- Optimized TD_IFFT Configuration' as Code
UNION ALL SELECT 'SELECT * FROM TD_IFFT ('
UNION ALL SELECT '    ON uaf_ifft_prepared'
UNION ALL SELECT '    USING'
UNION ALL SELECT '    Normalize (' || RecommendedNormalize || '),' FROM ifft_normalization_analysis
UNION ALL SELECT '    OutputFormat (''' || RecommendedFormat || '''),' FROM ifft_output_format_recommendation
UNION ALL SELECT '    IFFTSize (' || CAST(optimal_size_power2 AS VARCHAR(10)) || ')' FROM ifft_size_optimization
UNION ALL SELECT ') AS dt;';

/*
PARAMETER OPTIMIZATION SUMMARY:

1. NORMALIZATION:
   - TRUE: Scale output to prevent overflow
   - FALSE: Preserve absolute magnitude from FFT

2. OUTPUT FORMAT:
   - REAL: Real-valued time series (default)
   - COMPLEX: Complex-valued output (if input lacks Hermitian symmetry)

3. IFFT SIZE:
   - Must match or be power of 2
   - Determines output signal length
   - Affects time resolution

4. QUALITY FACTORS:
   - Spectral completeness
   - Frequency coverage
   - Phase continuity
   - Hermitian symmetry

NEXT STEPS:
□ Review parameter recommendations
□ Update td_ifft_workflow.sql with optimized parameters
□ Execute TD_IFFT with recommended configuration
□ Validate reconstruction quality
*/
