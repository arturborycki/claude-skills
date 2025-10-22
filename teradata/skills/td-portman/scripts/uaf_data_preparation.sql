-- UAF Data Preparation for TD_PORTMAN (Portmanteau Test)
-- Prepares time series data for UAF Model Preparation workflows
-- Focus: Model diagnostics, residual testing, autocorrelation testing, model validation

-- INSTRUCTIONS:
-- 1. Replace {USER_DATABASE} with your database name
-- 2. Replace {USER_TABLE} with your time series table name or residuals table
-- 3. Replace {TIMESTAMP_COLUMN} with your time column
-- 4. Replace {VALUE_COLUMNS} with residual values or series values
-- 5. Replace {MODEL_TABLE} with fitted model table (if testing model residuals)

-- ============================================================================
-- STEP 1: Residual Series Preparation
-- ============================================================================

-- Option A: Extract residuals from fitted model
DROP TABLE IF EXISTS model_residuals;
CREATE MULTISET TABLE model_residuals AS (
    SELECT
        {TIMESTAMP_COLUMN} as ts,
        {VALUE_COLUMNS} as residual,
        ROW_NUMBER() OVER (ORDER BY {TIMESTAMP_COLUMN}) as time_index
    FROM {USER_DATABASE}.{MODEL_TABLE}
    WHERE {TIMESTAMP_COLUMN} IS NOT NULL
    AND {VALUE_COLUMNS} IS NOT NULL
    ORDER BY {TIMESTAMP_COLUMN}
) WITH DATA;

-- Option B: Calculate residuals from actual vs fitted values
DROP TABLE IF EXISTS calculated_residuals;
CREATE MULTISET TABLE calculated_residuals AS (
    SELECT
        a.{TIMESTAMP_COLUMN} as ts,
        a.{VALUE_COLUMNS} - f.fitted_value as residual,
        ROW_NUMBER() OVER (ORDER BY a.{TIMESTAMP_COLUMN}) as time_index
    FROM {USER_DATABASE}.{USER_TABLE} a
    INNER JOIN {USER_DATABASE}.{MODEL_TABLE} f
        ON a.{TIMESTAMP_COLUMN} = f.{TIMESTAMP_COLUMN}
    WHERE a.{VALUE_COLUMNS} IS NOT NULL
    AND f.fitted_value IS NOT NULL
    ORDER BY a.{TIMESTAMP_COLUMN}
) WITH DATA;

-- ============================================================================
-- STEP 2: Residual Quality Assessment
-- ============================================================================

-- Check residual properties (should be white noise)
SELECT
    'Residual Statistics' as MetricType,
    COUNT(*) as N,
    AVG(residual) as Mean,
    STDDEV(residual) as StdDev,
    MIN(residual) as MinResidual,
    MAX(residual) as MaxResidual,
    SKEWNESS(residual) as Skewness,
    KURTOSIS(residual) as Kurtosis,
    -- Ideal residuals have mean ≈ 0
    CASE
        WHEN ABS(AVG(residual)) < 0.01 * STDDEV(residual) THEN 'Good (Mean ≈ 0)'
        ELSE 'Warning (Mean != 0)'
    END as MeanCheck
FROM model_residuals;

-- ============================================================================
-- STEP 3: Autocorrelation Function (ACF) Calculation
-- ============================================================================

-- Calculate sample autocorrelation for lags 1-20
DROP TABLE IF EXISTS residual_acf;
CREATE MULTISET TABLE residual_acf AS (
    SELECT
        lag,
        COUNT(*) as n_pairs,
        -- Sample autocorrelation coefficient
        SUM((r1.residual - mean_res) * (r2.residual - mean_res)) /
            (COUNT(*) * NULLIFZERO(var_res)) as acf,
        -- Standard error for white noise: 1/sqrt(n)
        1.0 / SQRT(n_total) as se_white_noise,
        -- 95% confidence bounds
        1.96 / SQRT(n_total) as ci_95_upper,
        -1.96 / SQRT(n_total) as ci_95_lower
    FROM (
        SELECT r1.time_index, r1.residual, r2.residual as lag_residual,
               r2.time_index - r1.time_index as lag
        FROM model_residuals r1
        INNER JOIN model_residuals r2
            ON r2.time_index = r1.time_index + (r2.time_index - r1.time_index)
        WHERE r2.time_index > r1.time_index
        AND r2.time_index - r1.time_index <= 20
    ) pairs
    CROSS JOIN (
        SELECT AVG(residual) as mean_res,
               VARIANCE(residual) as var_res,
               COUNT(*) as n_total
        FROM model_residuals
    ) stats
    GROUP BY lag, mean_res, var_res, n_total
    ORDER BY lag
) WITH DATA;

-- Display ACF values
SELECT
    lag,
    CAST(acf AS DECIMAL(10,4)) as ACF,
    CAST(se_white_noise AS DECIMAL(10,4)) as SE,
    CAST(ci_95_lower AS DECIMAL(10,4)) as CI_95_Lower,
    CAST(ci_95_upper AS DECIMAL(10,4)) as CI_95_Upper,
    CASE
        WHEN ABS(acf) > ci_95_upper THEN 'Significant'
        ELSE 'Not Significant'
    END as Significance
FROM residual_acf
ORDER BY lag;

-- ============================================================================
-- STEP 4: Ljung-Box Test Statistic Preparation
-- ============================================================================

-- Prepare data for Ljung-Box Q-statistic calculation
DROP TABLE IF EXISTS ljung_box_prep;
CREATE MULTISET TABLE ljung_box_prep AS (
    SELECT
        h,
        n,
        acf,
        -- Component of Ljung-Box statistic: n*(n+2)*acf^2/(n-h)
        n * (n + 2) * (acf * acf) / NULLIFZERO(n - h) as lb_component
    FROM (
        SELECT
            lag as h,
            acf,
            (SELECT COUNT(*) FROM model_residuals) as n
        FROM residual_acf
        WHERE lag <= 20  -- Test up to lag 20
    ) prep
) WITH DATA;

-- Calculate cumulative Ljung-Box statistics for different lag values
DROP TABLE IF EXISTS ljung_box_statistics;
CREATE MULTISET TABLE ljung_box_statistics AS (
    SELECT
        h as max_lag,
        n as sample_size,
        SUM(lb_component) OVER (ORDER BY h ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as Q_statistic,
        -- Degrees of freedom (lag - number of model parameters)
        h - 0 as df,  -- Replace 0 with actual number of model parameters
        -- Critical value for chi-square at 95% confidence
        CASE h
            WHEN 1 THEN 3.841
            WHEN 2 THEN 5.991
            WHEN 3 THEN 7.815
            WHEN 4 THEN 9.488
            WHEN 5 THEN 11.070
            WHEN 10 THEN 18.307
            WHEN 15 THEN 24.996
            WHEN 20 THEN 31.410
            ELSE NULL
        END as chi_sq_95
    FROM ljung_box_prep
) WITH DATA;

-- ============================================================================
-- STEP 5: Portmanteau Test Results Summary
-- ============================================================================

-- Interpret Ljung-Box test results
SELECT
    max_lag,
    CAST(Q_statistic AS DECIMAL(10,4)) as Q_Statistic,
    df as DegreesOfFreedom,
    CAST(chi_sq_95 AS DECIMAL(10,4)) as ChiSq_95_CriticalValue,
    CASE
        WHEN Q_statistic > chi_sq_95 THEN 'Reject H0: Residuals are NOT white noise'
        WHEN Q_statistic <= chi_sq_95 THEN 'Fail to Reject H0: Residuals consistent with white noise'
        ELSE 'Unable to determine'
    END as TestResult,
    CASE
        WHEN Q_statistic > chi_sq_95 THEN 'Model may be inadequate - autocorrelation detected'
        ELSE 'Model appears adequate - no significant autocorrelation'
    END as Interpretation
FROM ljung_box_statistics
WHERE max_lag IN (5, 10, 15, 20)
ORDER BY max_lag;

-- ============================================================================
-- STEP 6: Box-Pierce Test Statistics
-- ============================================================================

-- Calculate Box-Pierce test (simpler alternative to Ljung-Box)
DROP TABLE IF EXISTS box_pierce_statistics;
CREATE MULTISET TABLE box_pierce_statistics AS (
    SELECT
        h as max_lag,
        n as sample_size,
        -- Box-Pierce Q-statistic: n * sum(acf^2)
        n * SUM(acf * acf) OVER (ORDER BY h ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as Q_BP_statistic,
        h - 0 as df  -- Replace 0 with actual number of model parameters
    FROM (
        SELECT
            lag as h,
            acf,
            (SELECT COUNT(*) FROM model_residuals) as n
        FROM residual_acf
        WHERE lag <= 20
    ) prep
) WITH DATA;

-- ============================================================================
-- STEP 7: Residual Diagnostic Plots Data
-- ============================================================================

-- Prepare data for residual diagnostic visualizations
DROP TABLE IF EXISTS residual_diagnostics;
CREATE MULTISET TABLE residual_diagnostics AS (
    SELECT
        r.time_index,
        r.ts,
        r.residual,
        -- Standardized residuals
        (r.residual - mean_res) / NULLIFZERO(stddev_res) as standardized_residual,
        -- Squared residuals for heteroskedasticity check
        r.residual * r.residual as squared_residual,
        -- Absolute residuals
        ABS(r.residual) as abs_residual,
        -- Cumulative sum of residuals
        SUM(r.residual) OVER (ORDER BY r.time_index) as cumsum_residual,
        -- ACF values for this observation
        (SELECT acf FROM residual_acf WHERE lag = 1) as acf_lag1
    FROM model_residuals r
    CROSS JOIN (
        SELECT AVG(residual) as mean_res, STDDEV(residual) as stddev_res
        FROM model_residuals
    ) stats
) WITH DATA;

-- ============================================================================
-- STEP 8: UAF-Ready Dataset for Portmanteau Test
-- ============================================================================

-- Final dataset ready for TD_PORTMAN
DROP TABLE IF EXISTS uaf_portman_ready;
CREATE MULTISET TABLE uaf_portman_ready AS (
    SELECT
        r.time_index,
        r.ts as timestamp_col,
        r.residual as residual_value,
        d.standardized_residual,
        d.squared_residual,
        d.abs_residual,
        -- ACF metadata
        (SELECT COUNT(*) FROM residual_acf WHERE ABS(acf) > ci_95_upper) as n_significant_acf_lags,
        -- Test statistics
        (SELECT Q_statistic FROM ljung_box_statistics WHERE max_lag = 10) as ljung_box_Q10,
        (SELECT Q_statistic FROM ljung_box_statistics WHERE max_lag = 20) as ljung_box_Q20
    FROM model_residuals r
    INNER JOIN residual_diagnostics d ON r.time_index = d.time_index
    ORDER BY r.time_index
) WITH DATA;

-- Summary report
SELECT
    'Portmanteau Test Data Summary' as ReportType,
    COUNT(*) as TotalResiduals,
    AVG(residual_value) as MeanResidual,
    STDDEV(residual_value) as StdDevResidual,
    MIN(residual_value) as MinResidual,
    MAX(residual_value) as MaxResidual,
    MAX(n_significant_acf_lags) as SignificantACFLags,
    MAX(ljung_box_Q10) as LjungBox_Q10,
    MAX(ljung_box_Q20) as LjungBox_Q20,
    CASE
        WHEN MAX(ljung_box_Q10) > 18.307 THEN 'Model Inadequate (Q10 significant)'
        WHEN MAX(ljung_box_Q20) > 31.410 THEN 'Model Inadequate (Q20 significant)'
        ELSE 'Model Adequate (No significant autocorrelation)'
    END as OverallAssessment
FROM uaf_portman_ready;

-- Export prepared data
SELECT * FROM uaf_portman_ready
ORDER BY time_index;

/*
PORTMANTEAU TEST CHECKLIST:
□ Extract or calculate model residuals
□ Verify residuals have mean ≈ 0
□ Calculate autocorrelation function (ACF)
□ Compute Ljung-Box Q-statistics for multiple lags
□ Compare Q-statistics to chi-square critical values
□ Check Box-Pierce statistics as alternative
□ Identify significant autocorrelation lags
□ Assess overall model adequacy

LJUNG-BOX TEST INTERPRETATION:
- Null Hypothesis (H0): Residuals are white noise (no autocorrelation)
- Alternative Hypothesis (H1): Residuals exhibit autocorrelation
- If Q > Critical Value: Reject H0 (model inadequate)
- If Q ≤ Critical Value: Fail to reject H0 (model adequate)
- Commonly test at lags: 10, 15, 20 (or sqrt(n))

RESIDUAL DIAGNOSTICS INDICATORS:
1. ACF Plot: Should show no significant spikes beyond lag 0
2. Mean of Residuals: Should be close to zero
3. Variance: Should be constant over time (homoskedasticity)
4. Distribution: Should approximate normal distribution
5. Independence: No patterns or autocorrelation
6. Ljung-Box Test: Q-statistic below critical value

MODEL ADEQUACY ASSESSMENT:
GOOD MODEL:
- Ljung-Box Q < Critical Value
- ACF within confidence bounds
- Residuals mean ≈ 0
- Constant variance
- No patterns in residuals

POOR MODEL:
- Ljung-Box Q > Critical Value
- Multiple significant ACF lags
- Residuals mean != 0
- Heteroskedasticity present
- Systematic patterns in residuals

NEXT STEPS:
1. Review residual statistics and ACF plot
2. Interpret Ljung-Box test results
3. Proceed to td_portman_workflow.sql for UAF execution
4. If test indicates model inadequacy:
   - Consider additional AR/MA terms
   - Check for missing seasonal components
   - Investigate structural breaks
   - Re-specify model and retest
5. Document model diagnostic results
*/
