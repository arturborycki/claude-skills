-- =====================================================
-- TD_NgramSplitter - Parameter Tuning
-- =====================================================
-- Test different n-gram sizes
-- Unigrams only
DROP TABLE IF EXISTS {database}.ngrams_1;
CREATE MULTISET TABLE {database}.ngrams_1 AS (
    SELECT * FROM TD_NgramSplitter (
        ON {database}.ngram_input AS InputTable
        USING TextColumn ('text_content') Grams (1) Accumulate ('doc_id')
    ) as dt
) WITH DATA;

-- Bigrams only  
DROP TABLE IF EXISTS {database}.ngrams_2;
CREATE MULTISET TABLE {database}.ngrams_2 AS (
    SELECT * FROM TD_NgramSplitter (
        ON {database}.ngram_input AS InputTable
        USING TextColumn ('text_content') Grams (2) Accumulate ('doc_id')
    ) as dt
) WITH DATA;

-- Compare results
SELECT
    '1-grams' as config,
    COUNT(DISTINCT ngram) as unique_ngrams
FROM {database}.ngrams_1
UNION ALL
SELECT
    '2-grams' as config,
    COUNT(DISTINCT ngram) as unique_ngrams
FROM {database}.ngrams_2
UNION ALL
SELECT
    '1,2,3-grams' as config,
    COUNT(DISTINCT ngram) as unique_ngrams
FROM {database}.ngrams
ORDER BY unique_ngrams DESC;
-- =====================================================
