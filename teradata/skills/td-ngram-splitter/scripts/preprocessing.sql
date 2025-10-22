-- =====================================================
-- TD_NgramSplitter - Text Preprocessing
-- =====================================================
-- Purpose: Prepare text data for n-gram extraction
-- Function: TD_NgramSplitter
-- =====================================================

-- Check input text data
SELECT TOP 10
    {id_column},
    {text_column},
    LENGTH({text_column}) as text_length
FROM {database}.{text_table}
ORDER BY {id_column};

-- Clean and prepare text
DROP TABLE IF EXISTS {database}.ngram_input;
CREATE MULTISET TABLE {database}.ngram_input AS (
    SELECT
        {id_column} as doc_id,
        LOWER(TRIM({text_column})) as text_content
    FROM {database}.{text_table}
    WHERE {text_column} IS NOT NULL
      AND TRIM({text_column}) <> ''
) WITH DATA;

-- Text statistics
SELECT
    COUNT(*) as total_documents,
    AVG(LENGTH(text_content)) as avg_text_length,
    MIN(LENGTH(text_content)) as min_text_length,
    MAX(LENGTH(text_content)) as max_text_length,
    AVG(LENGTH(text_content) - LENGTH(REPLACE(text_content, ' ', '')) + 1) as avg_word_count
FROM {database}.ngram_input;

-- Ready for n-gram extraction
SELECT
    'Preprocessing Complete' as status,
    COUNT(*) as documents_ready
FROM {database}.ngram_input;
-- =====================================================
