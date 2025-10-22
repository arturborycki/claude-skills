-- =====================================================
-- TD_NgramSplitter - Evaluation
-- =====================================================
-- Most frequent n-grams
SELECT
    ngram,
    COUNT(*) as frequency,
    COUNT(DISTINCT doc_id) as doc_frequency
FROM {database}.ngrams
GROUP BY 1
ORDER BY 2 DESC
LIMIT 50;

-- N-gram coverage
SELECT
    LENGTH(ngram) - LENGTH(REPLACE(ngram, ' ', '')) + 1 as ngram_size,
    COUNT(DISTINCT ngram) as unique_ngrams,
    SUM(frequency) as total_occurrences
FROM (
    SELECT ngram, COUNT(*) as frequency
    FROM {database}.ngrams
    GROUP BY 1
) t
GROUP BY 1
ORDER BY 1;
-- =====================================================
