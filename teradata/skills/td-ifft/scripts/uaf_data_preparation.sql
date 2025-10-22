-- UAF Data Preparation for TD_IFFT
-- Prepares frequency domain data for Inverse Fast Fourier Transform
-- Teradata Unbounded Array Framework implementation

-- INSTRUCTIONS:
-- 1. Replace {USER_DATABASE} with your database name
-- 2. Replace {FFT_RESULTS_TABLE} with your FFT output table name
-- 3. Ensure FFT results contain complex or magnitude/phase components
-- 4. Verify frequency bin completeness before IFFT

-- ============================================================================
-- SECTION 1: FFT Results Validation
-- ============================================================================

-- Verify FFT output structure for IFFT compatibility
SELECT
    'FFT Results Validation' as CheckType,
    COUNT(*) as TotalFrequencyBins,
    COUNT(DISTINCT frequency_hz) as UniqueFrequencies,
    MIN(frequency_hz) as MinFreq_Hz,
    MAX(frequency_hz) as MaxFreq_Hz,
    COUNT(CASE WHEN real_part IS NOT NULL THEN 1 END) as ComplexReal_Count,
    COUNT(CASE WHEN imag_part IS NOT NULL THEN 1 END) as ComplexImag_Count,
    COUNT(CASE WHEN magnitude IS NOT NULL THEN 1 END) as Magnitude_Count,
    COUNT(CASE WHEN phase_degrees IS NOT NULL THEN 1 END) as Phase_Count,
    CASE
        WHEN COUNT(CASE WHEN real_part IS NOT NULL AND imag_part IS NOT NULL THEN 1 END) = COUNT(*)
        THEN 'COMPLEX format detected - Ready for IFFT'
        WHEN COUNT(CASE WHEN magnitude IS NOT NULL AND phase_degrees IS NOT NULL THEN 1 END) = COUNT(*)
        THEN 'MAGNITUDE_PHASE format - Conversion needed'
        ELSE 'INCOMPLETE data - Check FFT output format'
    END as DataFormatStatus
FROM {USER_DATABASE}.{FFT_RESULTS_TABLE};

-- ============================================================================
-- SECTION 2: Frequency Bin Completeness Check
-- ============================================================================

-- Ensure all frequency bins are present (no gaps)
DROP TABLE IF EXISTS frequency_continuity_check;
CREATE MULTISET TABLE frequency_continuity_check AS (
    SELECT
        expected_bins,
        actual_bins,
        expected_bins - actual_bins as missing_bins,
        CASE
            WHEN expected_bins = actual_bins THEN 'COMPLETE: All frequency bins present'
            ELSE 'INCOMPLETE: Missing ' || CAST(expected_bins - actual_bins AS VARCHAR(10)) || ' bins'
        END as CompletenessStatus
    FROM (
        SELECT
            POWER(2, CEILING(LOG(2, COUNT(*)))) as expected_bins,
            COUNT(*) as actual_bins
        FROM {USER_DATABASE}.{FFT_RESULTS_TABLE}
    ) t
) WITH DATA;

SELECT * FROM frequency_continuity_check;

-- ============================================================================
-- SECTION 3: Complex Number Conversion (if needed)
-- ============================================================================

-- Convert magnitude/phase to complex form if necessary
DROP TABLE IF EXISTS ifft_complex_data;
CREATE MULTISET TABLE ifft_complex_data AS (
    SELECT
        frequency_hz,
        frequency_bin,
        CASE
            WHEN real_part IS NOT NULL THEN real_part
            WHEN magnitude IS NOT NULL AND phase_degrees IS NOT NULL
            THEN magnitude * COS(phase_degrees * 3.14159265359 / 180.0)
            ELSE 0.0
        END as real_component,
        CASE
            WHEN imag_part IS NOT NULL THEN imag_part
            WHEN magnitude IS NOT NULL AND phase_degrees IS NOT NULL
            THEN magnitude * SIN(phase_degrees * 3.14159265359 / 180.0)
            ELSE 0.0
        END as imaginary_component,
        magnitude,
        phase_degrees
    FROM {USER_DATABASE}.{FFT_RESULTS_TABLE}
) WITH DATA;

-- ============================================================================
-- SECTION 4: Nyquist Symmetry Validation
-- ============================================================================

-- Verify FFT output satisfies Hermitian symmetry for real signals
DROP TABLE IF EXISTS nyquist_symmetry_check;
CREATE MULTISET TABLE nyquist_symmetry_check AS (
    SELECT
        'Hermitian Symmetry Check' as ValidationStep,
        positive_freqs,
        negative_freqs,
        CASE
            WHEN positive_freqs = negative_freqs OR negative_freqs = 0
            THEN 'VALID: Proper FFT symmetry for real signal reconstruction'
            ELSE 'WARNING: Asymmetric spectrum - May produce complex IFFT output'
        END as SymmetryStatus,
        nyquist_magnitude,
        dc_magnitude
    FROM (
        SELECT
            COUNT(CASE WHEN frequency_hz > 0 THEN 1 END) as positive_freqs,
            COUNT(CASE WHEN frequency_hz < 0 THEN 1 END) as negative_freqs,
            MAX(CASE WHEN frequency_hz = (SELECT MAX(frequency_hz) FROM ifft_complex_data) THEN magnitude END) as nyquist_magnitude,
            MAX(CASE WHEN frequency_hz = 0 THEN magnitude END) as dc_magnitude
        FROM ifft_complex_data
    ) t
) WITH DATA;

SELECT * FROM nyquist_symmetry_check;

-- ============================================================================
-- SECTION 5: Frequency Filtering (Optional)
-- ============================================================================

-- Apply frequency domain filtering before IFFT if needed
DROP TABLE IF EXISTS ifft_filtered_spectrum;
CREATE MULTISET TABLE ifft_filtered_spectrum AS (
    SELECT
        frequency_hz,
        frequency_bin,
        CASE
            -- Example: Remove DC component
            WHEN frequency_hz = 0 THEN real_component * 0.0
            -- Example: Low-pass filter (keep frequencies < 10 Hz)
            -- WHEN ABS(frequency_hz) > 10.0 THEN real_component * 0.0
            -- Example: High-pass filter (remove frequencies < 1 Hz)
            -- WHEN ABS(frequency_hz) < 1.0 THEN real_component * 0.0
            -- Example: Band-pass filter (keep 5-20 Hz)
            -- WHEN ABS(frequency_hz) NOT BETWEEN 5.0 AND 20.0 THEN real_component * 0.0
            ELSE real_component
        END as filtered_real,
        CASE
            WHEN frequency_hz = 0 THEN imaginary_component * 0.0
            ELSE imaginary_component
        END as filtered_imag,
        SQRT(POWER(real_component, 2) + POWER(imaginary_component, 2)) as original_magnitude,
        SQRT(POWER(
            CASE WHEN frequency_hz = 0 THEN real_component * 0.0 ELSE real_component END, 2) +
            POWER(CASE WHEN frequency_hz = 0 THEN imaginary_component * 0.0 ELSE imaginary_component END, 2)
        ) as filtered_magnitude
    FROM ifft_complex_data
) WITH DATA;

SELECT
    'Filtering Summary' as Operation,
    SUM(original_magnitude) as OriginalTotalMagnitude,
    SUM(filtered_magnitude) as FilteredTotalMagnitude,
    (SUM(original_magnitude) - SUM(filtered_magnitude)) / NULLIFZERO(SUM(original_magnitude)) * 100 as EnergyReduced_Pct
FROM ifft_filtered_spectrum;

-- ============================================================================
-- SECTION 6: IFFT Size Validation
-- ============================================================================

-- Verify IFFT size is power of 2 for optimal performance
DROP TABLE IF EXISTS ifft_size_validation;
CREATE MULTISET TABLE ifft_size_validation AS (
    SELECT
        'IFFT Size Analysis' as AnalysisType,
        spectrum_size,
        ifft_size_power2,
        CASE
            WHEN spectrum_size = ifft_size_power2 THEN 'OPTIMAL: Size is power of 2'
            WHEN spectrum_size > ifft_size_power2 / 2 THEN 'ACCEPTABLE: Close to power of 2'
            ELSE 'SUBOPTIMAL: Consider padding or truncation'
        END as SizeOptimality,
        expected_output_samples,
        time_resolution_sec
    FROM (
        SELECT
            COUNT(*) as spectrum_size,
            POWER(2, CEILING(LOG(2, COUNT(*)))) as ifft_size_power2,
            COUNT(*) as expected_output_samples,
            1.0 / (2.0 * MAX(frequency_hz)) as time_resolution_sec
        FROM ifft_filtered_spectrum
        WHERE frequency_hz > 0
    ) t
) WITH DATA;

SELECT * FROM ifft_size_validation;

-- ============================================================================
-- SECTION 7: Prepare Final IFFT Input
-- ============================================================================

-- Create final table for TD_IFFT input
DROP TABLE IF EXISTS uaf_ifft_prepared;
CREATE MULTISET TABLE uaf_ifft_prepared AS (
    SELECT
        frequency_bin as freq_index,
        frequency_hz,
        filtered_real as real_part,
        filtered_imag as imag_part,
        -- Alternative: Provide magnitude and phase
        filtered_magnitude as magnitude,
        CASE
            WHEN filtered_real = 0 AND filtered_imag = 0 THEN 0
            ELSE ATAN2(filtered_imag, filtered_real) * 180.0 / 3.14159265359
        END as phase_degrees,
        -- Metadata for validation
        ROW_NUMBER() OVER (ORDER BY frequency_hz) as sequence_id
    FROM ifft_filtered_spectrum
    ORDER BY frequency_hz
) WITH DATA;

-- ============================================================================
-- SECTION 8: Pre-IFFT Statistics
-- ============================================================================

SELECT
    'Pre-IFFT Statistics' as MetricType,
    COUNT(*) as TotalFrequencyBins,
    MIN(frequency_hz) as MinFrequency_Hz,
    MAX(frequency_hz) as MaxFrequency_Hz,
    MAX(frequency_hz) - MIN(frequency_hz) as FrequencyRange_Hz,
    SUM(magnitude) as TotalSpectralEnergy,
    AVG(magnitude) as AvgMagnitude,
    MAX(magnitude) as PeakMagnitude,
    STDDEV(magnitude) as MagnitudeStdDev,
    -- Expected output characteristics
    (SELECT expected_output_samples FROM ifft_size_validation) as ExpectedOutputSamples,
    (SELECT time_resolution_sec FROM ifft_size_validation) as TimeResolution_Sec
FROM uaf_ifft_prepared;

-- Verify data preparation is complete
SELECT
    'IFFT Preparation Status' as Status,
    COUNT(*) as PreparedFrequencyBins,
    COUNT(CASE WHEN real_part IS NOT NULL AND imag_part IS NOT NULL THEN 1 END) as ComplexPairs,
    MIN(freq_index) as FirstBin,
    MAX(freq_index) as LastBin,
    CURRENT_TIMESTAMP as PreparationTime
FROM uaf_ifft_prepared;

/*
UAF IFFT DATA PREPARATION CHECKLIST:
□ FFT results validated and complete
□ All frequency bins present (no gaps)
□ Complex number format verified (real + imaginary)
□ Hermitian symmetry checked (for real signal output)
□ Optional frequency filtering applied
□ IFFT size optimized (power of 2)
□ Nyquist frequency validated
□ Ready to proceed with TD_IFFT execution

NOTES:
- IFFT reconstructs time-domain signal from frequency components
- Input must have consistent format (complex or magnitude/phase)
- Hermitian symmetry ensures real-valued output signal
- Filtering in frequency domain modifies reconstructed signal
- Output length = number of frequency bins
- Normalization factor may affect amplitude scaling
- Phase information critical for accurate reconstruction

COMMON IFFT USE CASES:
- Signal reconstruction after frequency filtering
- Time-domain synthesis from spectral components
- Audio/video signal processing
- Communication signal demodulation
- Noise reduction in frequency domain
- Spectral editing and manipulation
*/
