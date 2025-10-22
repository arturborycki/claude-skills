-- =====================================================
-- TD_TFIDF - Text Preprocessing
-- =====================================================
-- Purpose: Prepare text data for TF-IDF transformation
-- Functions: TD_TFIDF, TD_TFIDFTransform
-- =====================================================

-- Check input text data
SELECT TOP 10
    {id_column},
    {text_column},
    LENGTH({text_column}) as text_length,
    LENGTH({text_column}) - LENGTH(REPLACE({text_column}, ' ', '')) + 1 as word_count_approx
FROM {database}.{text_table}
ORDER BY {id_column};

-- Text statistics
SELECT
    COUNT(*) as total_documents,
    COUNT({text_column}) as non_null_texts,
    AVG(LENGTH({text_column})) as avg_text_length,
    MIN(LENGTH({text_column})) as min_text_length,
    MAX(LENGTH({text_column})) as max_text_length
FROM {database}.{text_table};

-- Clean and prepare text data
DROP TABLE IF EXISTS {database}.tfidf_input;
CREATE MULTISET TABLE {database}.tfidf_input AS (
    SELECT
        {id_column} as doc_id,
        LOWER(TRIM({text_column})) as text_content
    FROM {database}.{text_table}
    WHERE {text_column} IS NOT NULL
      AND TRIM({text_column}) <> ''
      AND LENGTH({text_column}) > 0
) WITH DATA;

-- Remove empty documents
DELETE FROM {database}.tfidf_input
WHERE text_content IS NULL OR TRIM(text_content) = '';

-- Verify cleaned data
SELECT
    COUNT(*) as total_documents,
    AVG(LENGTH(text_content)) as avg_length,
    MIN(LENGTH(text_content)) as min_length,
    MAX(LENGTH(text_content)) as max_length
FROM {database}.tfidf_input;

-- Check for duplicates
SELECT
    doc_id,
    COUNT(*) as dup_count
FROM {database}.tfidf_input
GROUP BY 1
HAVING COUNT(*) > 1;

-- Ready for TD_TFIDF
SELECT
    'Text Preprocessing Complete' as status,
    COUNT(*) as documents_ready,
    CASE
        WHEN COUNT(*) >= 10 THEN 'READY FOR TD_TFIDF'
        ELSE 'WARNING - Small corpus'
    END as readiness
FROM {database}.tfidf_input;
-- =====================================================
