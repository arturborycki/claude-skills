-- UAF Data Preparation for TD_CONVOLUTION
-- Convolution operations for signal processing and filtering

DROP TABLE IF EXISTS uaf_convolution_prepared;
CREATE MULTISET TABLE uaf_convolution_prepared AS (
    SELECT
        {TIMESTAMP_COLUMN} as time_index,
        {VALUE_COLUMNS} as signal_value,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as sample_id
    FROM {USER_DATABASE}.{USER_TABLE}
    WHERE {VALUE_COLUMNS} IS NOT NULL
) WITH DATA;

-- Prepare kernel/impulse response
DROP TABLE IF EXISTS convolution_kernel;
CREATE MULTISET TABLE convolution_kernel AS (
    SELECT
        kernel_index,
        kernel_value,
        -- Example: Gaussian smoothing kernel
        CASE
            WHEN kernel_index = 0 THEN 0.4
            WHEN ABS(kernel_index) = 1 THEN 0.25
            WHEN ABS(kernel_index) = 2 THEN 0.05
            ELSE 0.0
        END as gaussian_kernel
    FROM (
        SELECT kernel_index FROM (VALUES(-2),(-1),(0),(1),(2)) AS t(kernel_index)
    ) k
) WITH DATA;

-- Edge handling validation
SELECT
    'Convolution Setup' as Stage,
    (SELECT COUNT(*) FROM uaf_convolution_prepared) as SignalLength,
    (SELECT COUNT(*) FROM convolution_kernel) as KernelLength,
    (SELECT COUNT(*) FROM uaf_convolution_prepared) - (SELECT COUNT(*) FROM convolution_kernel) + 1 as OutputLength_Valid,
    'Edge padding required for full convolution' as Note
;
