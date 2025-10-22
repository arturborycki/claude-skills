-- =====================================================
-- TD_NgramSplitter - Data Quality Checks
-- =====================================================
SELECT
    'Text Quality Check' as check_name,
    COUNT(*) as total_docs,
    AVG(LENGTH(text_content)) as avg_length,
    SUM(CASE WHEN LENGTH(text_content) < 10 THEN 1 ELSE 0 END) as very_short_docs
FROM {database}.ngram_input;

-- N-gram extraction success
SELECT
    'N-gram Extraction Check' as check_name,
    COUNT(DISTINCT doc_id) as docs_with_ngrams,
    COUNT(*) as total_ngrams,
    CAST(COUNT(*) * 1.0 / COUNT(DISTINCT doc_id) AS DECIMAL(10,2)) as avg_ngrams_per_doc
FROM {database}.ngrams;
-- =====================================================
