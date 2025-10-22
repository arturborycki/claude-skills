-- =====================================================
-- TD_TFIDF - Evaluation
-- =====================================================
-- Purpose: Evaluate TF-IDF feature quality
-- =====================================================

-- Check feature sparsity
WITH doc_features AS (
    SELECT
        doc_id,
        COUNT(*) as n_features
    FROM {database}.tfidf_features
    GROUP BY 1
)
SELECT
    'Feature Sparsity Analysis' as analysis_type,
    (SELECT COUNT(DISTINCT term) FROM {database}.tfidf_model) as vocabulary_size,
    AVG(n_features) as avg_features_per_doc,
    MIN(n_features) as min_features,
    MAX(n_features) as max_features,
    CAST(AVG(n_features) * 100.0 / (SELECT COUNT(DISTINCT term) FROM {database}.tfidf_model) AS DECIMAL(5,2)) as density_pct
FROM doc_features;

-- Top terms by average TF-IDF
SELECT TOP 20
    term,
    COUNT(*) as n_docs,
    AVG(tfidf_value) as avg_tfidf,
    MAX(tfidf_value) as max_tfidf
FROM {database}.tfidf_features
GROUP BY 1
ORDER BY 3 DESC;

-- Document similarity (cosine similarity sample)
WITH doc_vectors AS (
    SELECT
        doc_id,
        term,
        tfidf_value
    FROM {database}.tfidf_features
)
SELECT
    d1.doc_id as doc1,
    d2.doc_id as doc2,
    SUM(d1.tfidf_value * d2.tfidf_value) as dot_product,
    SQRT(SUM(d1.tfidf_value * d1.tfidf_value)) * SQRT(SUM(d2.tfidf_value * d2.tfidf_value)) as norm_product,
    SUM(d1.tfidf_value * d2.tfidf_value) / NULLIF(SQRT(SUM(d1.tfidf_value * d1.tfidf_value)) * SQRT(SUM(d2.tfidf_value * d2.tfidf_value)), 0) as cosine_similarity
FROM doc_vectors d1
INNER JOIN doc_vectors d2 ON d1.term = d2.term AND d1.doc_id < d2.doc_id
GROUP BY d1.doc_id, d2.doc_id
ORDER BY cosine_similarity DESC;
-- =====================================================
