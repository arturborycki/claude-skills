-- =====================================================
-- TD_TFIDF - Diagnostic Queries
-- =====================================================

-- Vocabulary analysis
SELECT
    'Vocabulary Statistics' as analysis_type,
    COUNT(DISTINCT term) as vocabulary_size,
    MIN(doc_freq) as min_doc_freq,
    MAX(doc_freq) as max_doc_freq,
    AVG(doc_freq) as avg_doc_freq,
    MIN(idf_weight) as min_idf,
    MAX(idf_weight) as max_idf,
    AVG(idf_weight) as avg_idf
FROM {database}.tfidf_model;

-- Term frequency distribution
SELECT
    CASE
        WHEN doc_freq = 1 THEN '1 document'
        WHEN doc_freq <= 5 THEN '2-5 documents'
        WHEN doc_freq <= 10 THEN '6-10 documents'
        WHEN doc_freq <= 50 THEN '11-50 documents'
        ELSE '>50 documents'
    END as frequency_bin,
    COUNT(*) as n_terms,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM {database}.tfidf_model
GROUP BY 1
ORDER BY MIN(doc_freq);

-- Most discriminative terms (highest IDF)
SELECT TOP 20
    term,
    doc_freq,
    CAST(idf_weight AS DECIMAL(10,6)) as idf_weight,
    'Rare term - high discriminative power' as interpretation
FROM {database}.tfidf_model
ORDER BY idf_weight DESC;

-- Least discriminative terms (lowest IDF)
SELECT TOP 20
    term,
    doc_freq,
    CAST(idf_weight AS DECIMAL(10,6)) as idf_weight,
    'Common term - low discriminative power' as interpretation
FROM {database}.tfidf_model
ORDER BY idf_weight ASC;

-- Per-document feature summary
SELECT
    doc_id,
    COUNT(*) as n_features,
    SUM(tfidf_value) as total_tfidf,
    AVG(tfidf_value) as avg_tfidf,
    MAX(tfidf_value) as max_tfidf
FROM {database}.tfidf_features
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;

-- Feature sparsity analysis
SELECT
    'Feature Sparsity' as metric,
    COUNT(DISTINCT doc_id) as n_documents,
    (SELECT COUNT(DISTINCT term) FROM {database}.tfidf_model) as vocabulary_size,
    COUNT(*) as non_zero_features,
    CAST(COUNT(*) * 100.0 / (COUNT(DISTINCT doc_id) * (SELECT COUNT(DISTINCT term) FROM {database}.tfidf_model)) AS DECIMAL(5,2)) as density_pct,
    100 - CAST(COUNT(*) * 100.0 / (COUNT(DISTINCT doc_id) * (SELECT COUNT(DISTINCT term) FROM {database}.tfidf_model)) AS DECIMAL(5,2)) as sparsity_pct
FROM {database}.tfidf_features;
-- =====================================================
