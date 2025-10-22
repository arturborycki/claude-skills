-- =====================================================
-- Simple Impute - Training/Fitting Script
-- =====================================================

DROP TABLE IF EXISTS {database}.impute_output;
CREATE MULTISET TABLE {database}.impute_output AS (
    SELECT * FROM TD_SimpleImpute (
        ON {database}.{input_table} AS InputTable
        USING
        -- Parameters specific to TD_SimpleImpute
        InputColumns ({column_list})
    ) as dt
) WITH DATA;

SELECT * FROM {database}.impute_output;

-- =====================================================
