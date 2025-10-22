-- =====================================================
-- TD_DFFT - Parameter Tuning
-- =====================================================

-- Test different FFT lengths
-- Length = 32
DROP TABLE IF EXISTS {database}.dfft_len32;
CREATE MULTISET TABLE {database}.dfft_len32 AS (
    SELECT * FROM TD_DFFT (
        ON (SELECT * FROM {database}.dfft_input_centered LIMIT 32) AS InputTable
        USING
        TargetColumn ('centered_value')
        SequenceIDColumn ('sequence_id')
        FFTLength (32)
        RealValuedSignal ('true')
    ) as dt
) WITH DATA;

-- Length = 64
DROP TABLE IF EXISTS {database}.dfft_len64;
CREATE MULTISET TABLE {database}.dfft_len64 AS (
    SELECT * FROM TD_DFFT (
        ON (SELECT * FROM {database}.dfft_input_centered LIMIT 64) AS InputTable
        USING
        TargetColumn ('centered_value')
        SequenceIDColumn ('sequence_id')
        FFTLength (64)
        RealValuedSignal ('true')
    ) as dt
) WITH DATA;

-- Compare frequency resolution
SELECT
    'FFT Length 32' as config,
    COUNT(*) as n_frequency_bins,
    MAX(frequency_bin) as max_frequency,
    'Lower resolution, faster' as characteristics
FROM {database}.dfft_len32

UNION ALL

SELECT
    'FFT Length 64' as config,
    COUNT(*) as n_frequency_bins,
    MAX(frequency_bin) as max_frequency,
    'Higher resolution, slower' as characteristics
FROM {database}.dfft_len64

UNION ALL

SELECT
    'Current FFT' as config,
    COUNT(*) as n_frequency_bins,
    MAX(frequency_bin) as max_frequency,
    'As configured' as characteristics
FROM {database}.dfft_output;

-- Recommendations
SELECT
    'FFT Length Selection' as recommendation_type,
    'Use longer FFT for better frequency resolution' as guideline_1,
    'Use power-of-2 lengths for computational efficiency' as guideline_2,
    'Pad with zeros if series length is not power-of-2' as guideline_3;
-- =====================================================
