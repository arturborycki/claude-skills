-- =====================================================
-- TD_TFIDF - Training (Fit IDF Weights)
-- =====================================================
-- Purpose: Calculate IDF weights from training corpus
-- Function: TD_TFIDF
-- =====================================================

-- Step 1: Fit TD_TFIDF on training data
DROP TABLE IF EXISTS {database}.tfidf_model;
CREATE MULTISET TABLE {database}.tfidf_model AS (
    SELECT * FROM TD_TFIDF (
        ON {database}.tfidf_input AS InputTable
        USING
        TextColumn ('text_content')
        DocIDColumn ('doc_id')
        OutputByWord ('true')
        MinDocFreq (2)  -- Ignore terms appearing in < 2 documents
        MaxDocFreq (0.8)  -- Ignore terms appearing in > 80% of documents
        TopK (1000)  -- Keep top 1000 terms by TF-IDF
        TermIgnoreList ('the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for')
    ) as dt
) WITH DATA;

-- View model vocabulary
SELECT TOP 20
    term,
    doc_freq,
    idf_weight
FROM {database}.tfidf_model
ORDER BY idf_weight DESC;

-- Vocabulary statistics
SELECT
    COUNT(DISTINCT term) as vocabulary_size,
    AVG(doc_freq) as avg_doc_frequency,
    MIN(idf_weight) as min_idf,
    MAX(idf_weight) as max_idf,
    AVG(idf_weight) as avg_idf
FROM {database}.tfidf_model;

-- Most common terms
SELECT TOP 20
    term,
    doc_freq as document_frequency,
    CAST(doc_freq * 100.0 / (SELECT COUNT(DISTINCT doc_id) FROM {database}.tfidf_input) AS DECIMAL(5,2)) as doc_pct
FROM {database}.tfidf_model
ORDER BY doc_freq DESC;

-- Rarest terms (highest IDF)
SELECT TOP 20
    term,
    doc_freq,
    CAST(idf_weight AS DECIMAL(10,6)) as idf_weight
FROM {database}.tfidf_model
ORDER BY idf_weight DESC;

-- Model training summary
SELECT
    'TD_TFIDF Model Training Summary' as report_type,
    (SELECT COUNT(DISTINCT doc_id) FROM {database}.tfidf_input) as training_documents,
    (SELECT COUNT(DISTINCT term) FROM {database}.tfidf_model) as vocabulary_size,
    (SELECT MAX(doc_freq) FROM {database}.tfidf_model) as max_term_frequency,
    CASE
        WHEN (SELECT COUNT(DISTINCT term) FROM {database}.tfidf_model) >= 100 THEN 'Good vocabulary size'
        ELSE 'WARNING - Small vocabulary'
    END as assessment;
-- =====================================================
