-- =====================================================
-- TD_NgramSplitter - Apply to New Text
-- =====================================================
DROP TABLE IF EXISTS {database}.new_text_ngrams;
CREATE MULTISET TABLE {database}.new_text_ngrams AS (
    SELECT * FROM TD_NgramSplitter (
        ON {database}.new_text_input AS InputTable
        USING
        TextColumn ('text_content')
        Grams (1,2,3)
        Accumulate ('doc_id')
    ) as dt
) WITH DATA;

SELECT doc_id, COUNT(*) as n_ngrams
FROM {database}.new_text_ngrams
GROUP BY 1
ORDER BY 2 DESC;
-- =====================================================
