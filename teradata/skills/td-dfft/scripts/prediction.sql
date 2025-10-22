-- =====================================================
-- TD_DFFT - Inverse FFT (IFFT)
-- =====================================================
-- Purpose: Transform frequency domain back to time domain
-- Note: Teradata may have TD_IDFFT for inverse transform
-- =====================================================

-- Apply inverse FFT (if available)
/*
DROP TABLE IF EXISTS {database}.ifft_output;
CREATE MULTISET TABLE {database}.ifft_output AS (
    SELECT * FROM TD_IDFFT (
        ON {database}.dfft_output AS InputTable
        USING
        RealColumn ('real_part')
        ImagColumn ('imaginary_part')
        SequenceIDColumn ('frequency_bin')
    ) as dt
) WITH DATA;

-- Verify reconstruction
SELECT
    o.sequence_id,
    o.value_col as original,
    r.reconstructed_value as reconstructed,
    ABS(o.value_col - r.reconstructed_value) as reconstruction_error
FROM {database}.dfft_input o
JOIN {database}.ifft_output r ON o.sequence_id = r.sequence_id
ORDER BY o.sequence_id;
*/

-- Filter and reconstruct (e.g., low-pass filter)
-- Keep only low-frequency components
DROP TABLE IF EXISTS {database}.dfft_filtered;
CREATE MULTISET TABLE {database}.dfft_filtered AS (
    SELECT
        frequency_bin,
        CASE WHEN frequency_bin <= 5 THEN real_part ELSE 0 END as real_part,
        CASE WHEN frequency_bin <= 5 THEN imaginary_part ELSE 0 END as imaginary_part
    FROM {database}.dfft_output
) WITH DATA;

SELECT
    'Frequency Filtering' as operation_type,
    'Low-pass filter applied (keeping frequencies 0-5)' as description;
-- =====================================================
