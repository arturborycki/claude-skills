-- Table Analysis Script for Dynamic SQL Generation
-- This script analyzes user table structure and generates optimized workflows

-- Step 1: Table Structure Discovery
SELECT
    ColumnName,
    ColumnType,
    Nullable,
    DefaultValue,
    CASE
        WHEN ColumnType IN ('INTEGER', 'BIGINT', 'DECIMAL', 'NUMERIC', 'FLOAT', 'DOUBLE PRECISION')
        THEN 'NUMERIC'
        WHEN ColumnType IN ('VARCHAR', 'CHAR', 'CLOB')
        THEN 'TEXT'
        WHEN ColumnType IN ('DATE', 'TIME', 'TIMESTAMP')
        THEN 'TEMPORAL'
        ELSE 'OTHER'
    END as DataCategory
FROM DBC.ColumnsV
WHERE DatabaseName = '{USER_DATABASE}'
AND TableName = '{USER_TABLE}'
ORDER BY ColumnId;

-- Step 2: Data Profile Analysis
SELECT
    'Table Statistics' as AnalysisType,
    COUNT(*) as TotalRows,
    COUNT(DISTINCT {ID_COLUMN}) as UniqueRecords,
    CURRENT_TIMESTAMP as AnalysisTime
FROM {USER_DATABASE}.{USER_TABLE};

-- Step 3: Generate Column Lists for ML Functions
SELECT
    'NUMERIC_COLUMNS' as ColumnType,
    LISTAGG('"' || ColumnName || '"', ',') WITHIN GROUP (ORDER BY ColumnId) as ColumnList
FROM DBC.ColumnsV
WHERE DatabaseName = '{USER_DATABASE}'
AND TableName = '{USER_TABLE}'
AND ColumnType IN ('INTEGER', 'BIGINT', 'DECIMAL', 'NUMERIC', 'FLOAT', 'DOUBLE PRECISION');

SELECT
    'CATEGORICAL_COLUMNS' as ColumnType,
    LISTAGG('"' || ColumnName || '"', ',') WITHIN GROUP (ORDER BY ColumnId) as ColumnList
FROM DBC.ColumnsV
WHERE DatabaseName = '{USER_DATABASE}'
AND TableName = '{USER_TABLE}'
AND ColumnType IN ('VARCHAR', 'CHAR', 'CLOB')
AND ColumnName != '{ID_COLUMN}';
