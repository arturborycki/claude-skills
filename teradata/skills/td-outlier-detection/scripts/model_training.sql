-- =====================================================
-- Outlier Detection - Training/Fitting Script
-- =====================================================

DROP TABLE IF EXISTS {database}.outlier_output;
CREATE MULTISET TABLE {database}.outlier_output AS (
    SELECT * FROM TD_OutlierDetection (
        ON {database}.{input_table} AS InputTable
        USING
        -- Parameters specific to TD_OutlierDetection
        InputColumns ({column_list})
    ) as dt
) WITH DATA;

SELECT * FROM {database}.outlier_output;

-- =====================================================
