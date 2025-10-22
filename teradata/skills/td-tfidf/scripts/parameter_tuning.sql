-- =====================================================
-- TD_TFIDF - Parameter Tuning
-- =====================================================

-- Test different MinDocFreq values
-- Option 1: MinDocFreq=1 (keep all terms)
DROP TABLE IF EXISTS {database}.tfidf_model_mindf1;
CREATE MULTISET TABLE {database}.tfidf_model_mindf1 AS (
    SELECT * FROM TD_TFIDF (
        ON {database}.tfidf_input AS InputTable
        USING
        TextColumn ('text_content')
        DocIDColumn ('doc_id')
        MinDocFreq (1)
        TopK (1000)
    ) as dt
) WITH DATA;

-- Option 2: MinDocFreq=5 (more aggressive filtering)
DROP TABLE IF EXISTS {database}.tfidf_model_mindf5;
CREATE MULTISET TABLE {database}.tfidf_model_mindf5 AS (
    SELECT * FROM TD_TFIDF (
        ON {database}.tfidf_input AS InputTable
        USING
        TextColumn ('text_content')
        DocIDColumn ('doc_id')
        MinDocFreq (5)
        TopK (1000)
    ) as dt
) WITH DATA;

-- Compare vocabulary sizes
SELECT
    'MinDocFreq=1' as config,
    COUNT(DISTINCT term) as vocab_size,
    AVG(doc_freq) as avg_doc_freq
FROM {database}.tfidf_model_mindf1

UNION ALL

SELECT
    'MinDocFreq=2' as config,
    COUNT(DISTINCT term) as vocab_size,
    AVG(doc_freq) as avg_doc_freq
FROM {database}.tfidf_model

UNION ALL

SELECT
    'MinDocFreq=5' as config,
    COUNT(DISTINCT term) as vocab_size,
    AVG(doc_freq) as avg_doc_freq
FROM {database}.tfidf_model_mindf5

ORDER BY vocab_size DESC;

-- Test different TopK values
SELECT
    'Parameter Tuning Recommendations' as recommendation_type,
    CASE
        WHEN (SELECT COUNT(DISTINCT term) FROM {database}.tfidf_model) < 50 THEN 'Decrease MinDocFreq or increase TopK'
        WHEN (SELECT COUNT(DISTINCT term) FROM {database}.tfidf_model) > 5000 THEN 'Increase MinDocFreq or decrease TopK'
        ELSE 'Current parameters seem reasonable'
    END as recommendation;
-- =====================================================
