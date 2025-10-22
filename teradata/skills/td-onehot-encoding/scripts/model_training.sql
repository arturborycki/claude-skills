-- =====================================================
-- One-Hot Encoding - Training/Fitting Script
-- =====================================================

DROP TABLE IF EXISTS {database}.ohe_output;
CREATE MULTISET TABLE {database}.ohe_output AS (
    SELECT * FROM TD_OneHotEncoder (
        ON {database}.{input_table} AS InputTable
        USING
        -- Parameters specific to TD_OneHotEncoder
        InputColumns ({column_list})
    ) as dt
) WITH DATA;

SELECT * FROM {database}.ohe_output;

-- =====================================================
