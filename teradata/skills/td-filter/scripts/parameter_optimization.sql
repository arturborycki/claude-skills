-- TD_FILTER Parameter Optimization

-- Filter Type Selection
DROP TABLE IF EXISTS filter_type_recommendation;
CREATE MULTISET TABLE filter_type_recommendation AS (
    SELECT
        'Filter Type Analysis' as AnalysisType,
        dc_component_ratio,
        high_freq_noise_ratio,
        CASE
            WHEN dc_component_ratio > 0.3 THEN 'HIGHPASS - Remove DC offset'
            WHEN high_freq_noise_ratio > 0.4 THEN 'LOWPASS - Remove high-freq noise'
            ELSE 'BANDPASS - Isolate frequency band of interest'
        END as RecommendedFilterType
    FROM (
        SELECT
            ABS(AVG(signal_value)) / (STDDEV(signal_value) + 0.001) as dc_component_ratio,
            STDDEV(signal_value - LAG(signal_value) OVER (ORDER BY sample_id)) / STDDEV(signal_value) as high_freq_noise_ratio
        FROM uaf_filter_prepared
    ) t
) WITH DATA;

-- Cutoff Frequency Recommendation
DROP TABLE IF EXISTS cutoff_frequency_recommendation;
CREATE MULTISET TABLE cutoff_frequency_recommendation AS (
    SELECT
        'Cutoff Frequency' as Parameter,
        nyquist_freq,
        ROUND(nyquist_freq * 0.1, 2) as Conservative_Hz,
        ROUND(nyquist_freq * 0.3, 2) as Moderate_Hz,
        ROUND(nyquist_freq * 0.5, 2) as Aggressive_Hz,
        'Set below Nyquist frequency based on noise characteristics' as Guidance
    FROM (
        SELECT (1.0 / AVG(sample_interval)) / 2.0 as nyquist_freq
        FROM (
            SELECT CAST((time_index - LAG(time_index) OVER (ORDER BY time_index)) SECOND AS FLOAT) as sample_interval
            FROM uaf_filter_prepared
            QUALIFY ROW_NUMBER() OVER (ORDER BY time_index) > 1
        ) t
    ) f
) WITH DATA;

SELECT * FROM filter_type_recommendation;
SELECT * FROM cutoff_frequency_recommendation;

-- Generate optimized TD_FILTER code
SELECT '-- Optimized TD_FILTER Configuration' as Code
UNION ALL SELECT 'SELECT * FROM TD_FILTER ('
UNION ALL SELECT '    ON uaf_filter_prepared'
UNION ALL SELECT '    USING'
UNION ALL SELECT '    FilterType (''' || RecommendedFilterType || '''),' FROM filter_type_recommendation
UNION ALL SELECT '    CutoffFrequency (' || CAST(Moderate_Hz AS VARCHAR(10)) || '),' FROM cutoff_frequency_recommendation
UNION ALL SELECT '    FilterOrder (4),'
UNION ALL SELECT '    PassType (''forward'')'
UNION ALL SELECT ') AS dt;';
