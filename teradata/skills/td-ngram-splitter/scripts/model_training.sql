-- =====================================================
-- TD_NgramSplitter - N-gram Extraction
-- =====================================================
DROP TABLE IF EXISTS {database}.ngrams;
CREATE MULTISET TABLE {database}.ngrams AS (
    SELECT * FROM TD_NgramSplitter (
        ON {database}.ngram_input AS InputTable
        USING
        TextColumn ('text_content')
        Grams (1,2,3)  -- Extract unigrams, bigrams, trigrams
        Delimiter (' ')
        ToLowerCase ('true')
        Accumulate ('doc_id')
    ) as dt
) WITH DATA;

SELECT TOP 20 * FROM {database}.ngrams;

-- N-gram statistics
SELECT
    ngram_size,
    COUNT(*) as n_ngrams,
    COUNT(DISTINCT ngram) as unique_ngrams
FROM (
    SELECT doc_id, ngram, LENGTH(ngram) - LENGTH(REPLACE(ngram, ' ', '')) + 1 as ngram_size
    FROM {database}.ngrams
) t
GROUP BY 1
ORDER BY 1;
-- =====================================================
