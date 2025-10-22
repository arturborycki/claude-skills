-- =====================================================
-- TD_TFIDF - Transform New Documents
-- =====================================================
-- Purpose: Apply TF-IDF transformation to new text data
-- Function: TD_TFIDFTransform
-- =====================================================

-- Step 1: Prepare new documents for transformation
DROP TABLE IF EXISTS {database}.new_documents;
CREATE MULTISET TABLE {database}.new_documents AS (
    SELECT
        {id_column} as doc_id,
        LOWER(TRIM({text_column})) as text_content
    FROM {database}.{new_text_table}
    WHERE {text_column} IS NOT NULL
) WITH DATA;

-- Step 2: Apply TF-IDF transformation
DROP TABLE IF EXISTS {database}.tfidf_features;
CREATE MULTISET TABLE {database}.tfidf_features AS (
    SELECT * FROM TD_TFIDFTransform (
        ON {database}.new_documents AS InputTable
        ON {database}.tfidf_model AS ModelTable
        USING
        TextColumn ('text_content')
        DocIDColumn ('doc_id')
        Accumulate ('doc_id')
    ) as dt
) WITH DATA;

-- View transformed features
SELECT TOP 10 * FROM {database}.tfidf_features
ORDER BY doc_id;

-- Check transformation coverage
SELECT
    COUNT(DISTINCT doc_id) as transformed_docs,
    COUNT(*) as total_features,
    CAST(COUNT(*) * 1.0 / COUNT(DISTINCT doc_id) AS DECIMAL(10,2)) as avg_features_per_doc
FROM {database}.tfidf_features;

-- Documents with no features (all terms filtered)
SELECT DISTINCT doc_id
FROM {database}.new_documents
WHERE doc_id NOT IN (SELECT DISTINCT doc_id FROM {database}.tfidf_features);

-- Feature statistics
SELECT
    doc_id,
    COUNT(*) as n_features,
    SUM(tfidf_value) as sum_tfidf,
    AVG(tfidf_value) as avg_tfidf,
    MAX(tfidf_value) as max_tfidf
FROM {database}.tfidf_features
GROUP BY 1
ORDER BY 2 DESC;
-- =====================================================
