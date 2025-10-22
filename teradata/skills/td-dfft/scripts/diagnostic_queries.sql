-- =====================================================
-- TD_DFFT - Diagnostic Queries
-- =====================================================

-- Full frequency spectrum
SELECT
    frequency_bin,
    CAST(real_part AS DECIMAL(12,6)) as real,
    CAST(imaginary_part AS DECIMAL(12,6)) as imag,
    CAST(SQRT(real_part*real_part + imaginary_part*imaginary_part) AS DECIMAL(12,6)) as magnitude,
    CAST(POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2) AS DECIMAL(12,6)) as power
FROM {database}.dfft_output
ORDER BY frequency_bin;

-- DC component (mean of signal)
SELECT
    'DC Component' as component_type,
    real_part as dc_value,
    'This represents the mean of the original signal' as interpretation
FROM {database}.dfft_output
WHERE frequency_bin = 0;

-- Dominant frequencies
SELECT TOP 20
    frequency_bin,
    CAST(SQRT(real_part*real_part + imaginary_part*imaginary_part) AS DECIMAL(12,6)) as magnitude,
    CAST(POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2) AS DECIMAL(12,6)) as power,
    CAST((SELECT COUNT(*) FROM {database}.dfft_input) * 1.0 / NULLIF(frequency_bin, 0) AS DECIMAL(10,2)) as period_samples
FROM {database}.dfft_output
WHERE frequency_bin > 0
ORDER BY power DESC;

-- Power spectral density
SELECT
    frequency_bin,
    CAST(POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2) / 
         (SELECT COUNT(*) FROM {database}.dfft_output) AS DECIMAL(12,6)) as psd
FROM {database}.dfft_output
WHERE frequency_bin > 0
ORDER BY frequency_bin
LIMIT 50;

-- Cumulative power (Parseval's theorem check)
SELECT
    'Power Distribution' as analysis_type,
    CAST(SUM(POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2)) AS DECIMAL(12,6)) as total_power_frequency,
    CAST((SELECT SUM(value_col * value_col) FROM {database}.dfft_input) AS DECIMAL(12,6)) as total_power_time,
    'Should be approximately equal (Parseval theorem)' as note
FROM {database}.dfft_output;

-- Frequency bins by power (histogram)
SELECT
    CASE
        WHEN POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2) < 0.01 THEN 'Very low power'
        WHEN POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2) < 0.1 THEN 'Low power'
        WHEN POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2) < 1.0 THEN 'Moderate power'
        WHEN POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2) < 10.0 THEN 'High power'
        ELSE 'Very high power'
    END as power_category,
    COUNT(*) as n_frequency_bins,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {database}.dfft_output
GROUP BY 1
ORDER BY MIN(POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2));
-- =====================================================
