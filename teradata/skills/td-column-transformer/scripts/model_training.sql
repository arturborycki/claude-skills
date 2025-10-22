-- =====================================================
-- Column Transformer - Training/Fitting Script
-- =====================================================

DROP TABLE IF EXISTS {database}.coltrans_output;
CREATE MULTISET TABLE {database}.coltrans_output AS (
    SELECT * FROM TD_ColumnTransformer (
        ON {database}.{input_table} AS InputTable
        USING
        -- Parameters specific to TD_ColumnTransformer
        InputColumns ({column_list})
    ) as dt
) WITH DATA;

SELECT * FROM {database}.coltrans_output;

-- =====================================================
