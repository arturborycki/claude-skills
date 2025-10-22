-- =====================================================
-- TD_NgramSplitter - Diagnostic Queries
-- =====================================================
-- Top unigrams
SELECT TOP 20
    ngram as unigram,
    COUNT(*) as frequency
FROM {database}.ngrams
WHERE ngram NOT LIKE '% %'
GROUP BY 1
ORDER BY 2 DESC;

-- Top bigrams
SELECT TOP 20
    ngram as bigram,
    COUNT(*) as frequency
FROM {database}.ngrams
WHERE LENGTH(ngram) - LENGTH(REPLACE(ngram, ' ', '')) = 1
GROUP BY 1
ORDER BY 2 DESC;

-- Top trigrams
SELECT TOP 20
    ngram as trigram,
    COUNT(*) as frequency
FROM {database}.ngrams
WHERE LENGTH(ngram) - LENGTH(REPLACE(ngram, ' ', '')) = 2
GROUP BY 1
ORDER BY 2 DESC;

-- N-gram distribution by size
SELECT
    CASE
        WHEN LENGTH(ngram) - LENGTH(REPLACE(ngram, ' ', '')) = 0 THEN 'unigram'
        WHEN LENGTH(ngram) - LENGTH(REPLACE(ngram, ' ', '')) = 1 THEN 'bigram'
        WHEN LENGTH(ngram) - LENGTH(REPLACE(ngram, ' ', '')) = 2 THEN 'trigram'
        ELSE 'longer'
    END as ngram_type,
    COUNT(*) as total_count,
    COUNT(DISTINCT ngram) as unique_count
FROM {database}.ngrams
GROUP BY 1
ORDER BY 1;
-- =====================================================
