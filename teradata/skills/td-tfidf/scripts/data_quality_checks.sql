-- =====================================================
-- TD_TFIDF - Data Quality Checks
-- =====================================================

-- Check 1: Text content validation
SELECT
    'Text Content Check' as check_name,
    COUNT(*) as total_docs,
    COUNT({text_column}) as non_null,
    SUM(CASE WHEN LENGTH(TRIM({text_column})) = 0 THEN 1 ELSE 0 END) as empty_texts,
    AVG(LENGTH({text_column})) as avg_length
FROM {database}.{text_table};

-- Check 2: Character encoding issues
SELECT
    doc_id,
    text_content,
    'Contains non-ASCII' as issue
FROM {database}.tfidf_input
WHERE text_content LIKE '%[^a-zA-Z0-9 ]%'
LIMIT 10;

-- Check 3: Very short documents
SELECT
    doc_id,
    LENGTH(text_content) as text_length,
    text_content
FROM {database}.tfidf_input
WHERE LENGTH(text_content) < 20
ORDER BY 2;

-- Check 4: Vocabulary coverage
SELECT
    'Vocabulary Coverage' as check_name,
    COUNT(DISTINCT term) as vocabulary_size,
    SUM(doc_freq) as total_term_occurrences,
    AVG(doc_freq) as avg_doc_freq,
    CASE
        WHEN COUNT(DISTINCT term) >= 100 THEN 'PASS - Good vocabulary'
        WHEN COUNT(DISTINCT term) >= 50 THEN 'WARNING - Small vocabulary'
        ELSE 'FAIL - Very small vocabulary'
    END as status
FROM {database}.tfidf_model;

-- Check 5: Feature density
SELECT
    'Feature Density' as check_name,
    COUNT(DISTINCT doc_id) as n_documents,
    COUNT(*) as total_features,
    (SELECT COUNT(DISTINCT term) FROM {database}.tfidf_model) as vocabulary_size,
    CAST(COUNT(*) * 100.0 / (COUNT(DISTINCT doc_id) * (SELECT COUNT(DISTINCT term) FROM {database}.tfidf_model)) AS DECIMAL(5,2)) as density_pct
FROM {database}.tfidf_features;
-- =====================================================
