-- =====================================================
-- TD_DFFT - Evaluation
-- =====================================================

-- Frequency spectrum analysis
SELECT
    CASE
        WHEN frequency_bin = 0 THEN 'DC component (mean)'
        WHEN frequency_bin <= (SELECT COUNT(*) FROM {database}.dfft_output) * 0.1 THEN 'Low frequency'
        WHEN frequency_bin <= (SELECT COUNT(*) FROM {database}.dfft_output) * 0.5 THEN 'Mid frequency'
        ELSE 'High frequency'
    END as frequency_range,
    COUNT(*) as n_components,
    SUM(POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2)) as total_power
FROM {database}.dfft_output
GROUP BY 1
ORDER BY MIN(frequency_bin);

-- Energy concentration
WITH power_spectrum AS (
    SELECT
        frequency_bin,
        POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2) as power
    FROM {database}.dfft_output
)
SELECT
    'Energy Concentration' as metric_type,
    SUM(power) as total_energy,
    SUM(CASE WHEN frequency_bin <= 10 THEN power ELSE 0 END) as low_freq_energy,
    CAST(SUM(CASE WHEN frequency_bin <= 10 THEN power ELSE 0 END) * 100.0 / SUM(power) AS DECIMAL(5,2)) as low_freq_percentage
FROM power_spectrum;

-- Identify periodic components
SELECT TOP 10
    frequency_bin,
    CAST((SELECT COUNT(*) FROM {database}.dfft_input) * 1.0 / NULLIF(frequency_bin, 0) AS DECIMAL(10,2)) as period_in_samples,
    CAST(POWER(SQRT(real_part*real_part + imaginary_part*imaginary_part), 2) AS DECIMAL(12,6)) as power
FROM {database}.dfft_output
WHERE frequency_bin > 0
ORDER BY power DESC;
-- =====================================================
