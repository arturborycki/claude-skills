-- =====================================================
-- Train-Test Split - Training/Fitting Script
-- =====================================================

DROP TABLE IF EXISTS {database}.split_output;
CREATE MULTISET TABLE {database}.split_output AS (
    SELECT * FROM TD_TrainTestSplit (
        ON {database}.{input_table} AS InputTable
        USING
        -- Parameters specific to TD_TrainTestSplit
        InputColumns ({column_list})
    ) as dt
) WITH DATA;

SELECT * FROM {database}.split_output;

-- =====================================================
