-- TD_WINDOW Parameter Optimization

DROP TABLE IF EXISTS window_function_selection;
CREATE MULTISET TABLE window_function_selection AS (
    SELECT
        leakage_risk,
        CASE
            WHEN leakage_risk = 'HIGH' THEN 'Blackman'
            WHEN leakage_risk = 'MEDIUM' THEN 'Hamming'
            ELSE 'Hanning'
        END as RecommendedWindow,
        CASE
            WHEN leakage_risk = 'HIGH' THEN 'High edge discontinuity - Use Blackman for maximum leakage reduction'
            WHEN leakage_risk = 'MEDIUM' THEN 'Moderate discontinuity - Hamming provides good balance'
            ELSE 'Low discontinuity - Hanning sufficient'
        END as Reasoning
    FROM edge_discontinuity_check
) WITH DATA;

SELECT * FROM window_function_selection;

-- Window size recommendation
SELECT
    'Window Size' as Parameter,
    COUNT(*) as SignalLength,
    POWER(2, CEILING(LOG(2, COUNT(*)))) as RecommendedSize_Power2,
    '50% overlap recommended for spectral analysis' as OverlapGuidance
FROM uaf_window_prepared;

SELECT '-- Optimized TD_WINDOW Configuration'
UNION ALL SELECT 'SELECT * FROM TD_WINDOW ('
UNION ALL SELECT '    ON uaf_window_prepared'
UNION ALL SELECT '    USING'
UNION ALL SELECT '    WindowType (''' || RecommendedWindow || '''),' FROM window_function_selection
UNION ALL SELECT '    WindowSize (256),'
UNION ALL SELECT '    Overlap (128)'
UNION ALL SELECT ') AS dt;';
