-- =====================================================
-- TD_DFFT - Apply FFT
-- =====================================================
-- Purpose: Transform time series to frequency domain
-- Function: TD_DFFT
-- Note: This is a transformation, not model training
-- =====================================================

-- Apply FFT
DROP TABLE IF EXISTS {database}.dfft_output;
CREATE MULTISET TABLE {database}.dfft_output AS (
    SELECT * FROM TD_DFFT (
        ON {database}.dfft_input_centered AS InputTable
        USING
        TargetColumn ('centered_value')
        SequenceIDColumn ('sequence_id')
        FFTLength (POWER(2, CAST(LOG(2, (SELECT COUNT(*) FROM {database}.dfft_input_centered)) AS INTEGER)))
        -- FFTLength should be power of 2
        RealValuedSignal ('true')  -- Input is real (not complex)
    ) as dt
) WITH DATA;

-- View FFT results (magnitude spectrum)
SELECT
    frequency_bin,
    CAST(real_part AS DECIMAL(12,6)) as real,
    CAST(imaginary_part AS DECIMAL(12,6)) as imag,
    CAST(SQRT(real_part*real_part + imaginary_part*imaginary_part) AS DECIMAL(12,6)) as magnitude,
    CAST(ATAN2(imaginary_part, real_part) AS DECIMAL(12,6)) as phase
FROM {database}.dfft_output
ORDER BY frequency_bin
LIMIT 50;

-- Power spectrum (squared magnitude)
SELECT
    frequency_bin,
    CAST(POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2) AS DECIMAL(12,6)) as power
FROM {database}.dfft_output
ORDER BY frequency_bin
LIMIT 50;

-- Dominant frequencies (highest power)
SELECT TOP 10
    frequency_bin,
    CAST(POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2) AS DECIMAL(12,6)) as power,
    'Dominant frequency component' as interpretation
FROM {database}.dfft_output
WHERE frequency_bin > 0  -- Exclude DC component
ORDER BY power DESC;

-- FFT summary
SELECT
    'FFT Analysis Summary' as summary_type,
    COUNT(*) as n_frequency_bins,
    (SELECT COUNT(*) FROM {database}.dfft_input) as n_time_points,
    MAX(POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2)) as max_power
FROM {database}.dfft_output;
-- =====================================================
