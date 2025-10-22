-- =====================================================
-- Scale Fit - Training/Fitting Script
-- =====================================================

DROP TABLE IF EXISTS {database}.scale_output;
CREATE MULTISET TABLE {database}.scale_output AS (
    SELECT * FROM TD_ScaleFit (
        ON {database}.{input_table} AS InputTable
        USING
        -- Parameters specific to TD_ScaleFit
        InputColumns ({column_list})
    ) as dt
) WITH DATA;

SELECT * FROM {database}.scale_output;

-- =====================================================
