-- Parameter Optimization for TD_PORTMAN (Portmanteau Test)
-- Grid search for residual diagnostic test configuration
-- Focus: Lag selection, confidence levels, test types, significance thresholds

-- INSTRUCTIONS:
-- 1. Run uaf_data_preparation.sql first to prepare residuals
-- 2. Configure test parameter grids
-- 3. Evaluate diagnostic test power and sensitivity
-- 4. Select optimal test configuration for model validation

-- ============================================================================
-- STEP 1: Portmanteau Test Parameter Grid
-- ============================================================================

DROP TABLE IF EXISTS portman_param_grid;
CREATE MULTISET TABLE portman_param_grid (
    test_config_id INTEGER,
    max_lags INTEGER,
    confidence_level DECIMAL(5,3),
    test_type VARCHAR(50),
    significance_threshold DECIMAL(5,3),
    df_adjustment INTEGER
);

INSERT INTO portman_param_grid VALUES
    -- Ljung-Box Test configurations
    (1, 5, 0.950, 'ljung_box', 0.05, 0),
    (2, 10, 0.950, 'ljung_box', 0.05, 0),
    (3, 15, 0.950, 'ljung_box', 0.05, 0),
    (4, 20, 0.950, 'ljung_box', 0.05, 0),
    (5, 10, 0.990, 'ljung_box', 0.01, 0),
    (6, 20, 0.990, 'ljung_box', 0.01, 0),

    -- Box-Pierce Test configurations
    (7, 5, 0.950, 'box_pierce', 0.05, 0),
    (8, 10, 0.950, 'box_pierce', 0.05, 0),
    (9, 15, 0.950, 'box_pierce', 0.05, 0),
    (10, 20, 0.950, 'box_pierce', 0.05, 0),

    -- With degrees of freedom adjustment for model parameters
    (11, 10, 0.950, 'ljung_box', 0.05, 2),
    (12, 10, 0.950, 'ljung_box', 0.05, 3),
    (13, 20, 0.950, 'ljung_box', 0.05, 2),
    (14, 20, 0.950, 'ljung_box', 0.05, 3),

    -- Conservative settings (99% confidence)
    (15, 10, 0.990, 'ljung_box', 0.01, 2),
    (16, 20, 0.990, 'ljung_box', 0.01, 3),

    -- Lenient settings (90% confidence)
    (17, 10, 0.900, 'ljung_box', 0.10, 0),
    (18, 20, 0.900, 'ljung_box', 0.10, 0);

-- ============================================================================
-- STEP 2: Test Results Template
-- ============================================================================

DROP TABLE IF EXISTS portman_test_results;
CREATE MULTISET TABLE portman_test_results (
    test_config_id INTEGER,
    max_lags INTEGER,
    confidence_level DECIMAL(5,3),
    test_type VARCHAR(50),
    significance_threshold DECIMAL(5,3),
    df_adjustment INTEGER,
    -- Test statistics
    Q_statistic DECIMAL(18,6),
    degrees_of_freedom INTEGER,
    p_value DECIMAL(10,8),
    critical_value DECIMAL(18,6),
    -- Test results
    reject_null_hypothesis INTEGER,
    autocorrelation_detected INTEGER,
    model_adequate INTEGER,
    -- Diagnostic details
    significant_lags INTEGER,
    max_acf_value DECIMAL(10,6),
    max_acf_lag INTEGER,
    -- Power analysis
    test_power DECIMAL(10,6),
    sensitivity_score DECIMAL(10,6),
    created_timestamp TIMESTAMP
);

-- ============================================================================
-- STEP 3: Simulate Portmanteau Tests for Each Configuration
-- ============================================================================

INSERT INTO portman_test_results
SELECT
    p.test_config_id,
    p.max_lags,
    p.confidence_level,
    p.test_type,
    p.significance_threshold,
    p.df_adjustment,
    -- Simulated Q-statistic (replace with actual TD_PORTMAN results)
    10.0 + (p.max_lags * 0.8) + (RANDOM() * 15.0) as Q_statistic,
    p.max_lags - p.df_adjustment as degrees_of_freedom,
    -- Simulated p-value
    0.15 + (RANDOM() * 0.30) as p_value,
    -- Critical value from chi-square distribution
    CASE p.max_lags - p.df_adjustment
        WHEN 5 THEN CASE WHEN p.confidence_level >= 0.99 THEN 15.086 ELSE 11.070 END
        WHEN 10 THEN CASE WHEN p.confidence_level >= 0.99 THEN 23.209 ELSE 18.307 END
        WHEN 15 THEN CASE WHEN p.confidence_level >= 0.99 THEN 30.578 ELSE 24.996 END
        WHEN 20 THEN CASE WHEN p.confidence_level >= 0.99 THEN 37.566 ELSE 31.410 END
        ELSE 18.307
    END as critical_value,
    -- Test decision
    CASE WHEN (0.15 + (RANDOM() * 0.30)) < p.significance_threshold THEN 1 ELSE 0 END as reject_null_hypothesis,
    CASE WHEN (0.15 + (RANDOM() * 0.30)) < p.significance_threshold THEN 1 ELSE 0 END as autocorrelation_detected,
    CASE WHEN (0.15 + (RANDOM() * 0.30)) >= p.significance_threshold THEN 1 ELSE 0 END as model_adequate,
    -- Diagnostic details
    CAST(p.max_lags * 0.15 + (RANDOM() * 3) AS INTEGER) as significant_lags,
    0.10 + (RANDOM() * 0.15) as max_acf_value,
    CAST(1 + (RANDOM() * p.max_lags) AS INTEGER) as max_acf_lag,
    -- Power analysis (simulated)
    0.75 + (p.max_lags * 0.01) - (RANDOM() * 0.10) as test_power,
    0.70 + (p.max_lags * 0.008) - (RANDOM() * 0.08) as sensitivity_score,
    CURRENT_TIMESTAMP
FROM portman_param_grid p;

-- ============================================================================
-- STEP 4: Test Type Comparison
-- ============================================================================

SELECT
    'Test Type Comparison' as AnalysisType,
    test_type,
    AVG(Q_statistic) as AvgQ_Statistic,
    AVG(p_value) as AvgP_Value,
    SUM(reject_null_hypothesis) as RejectionCount,
    COUNT(*) as TotalTests,
    CAST(SUM(reject_null_hypothesis) * 100.0 / COUNT(*) AS DECIMAL(6,2)) as RejectionRate,
    AVG(test_power) as AvgTestPower
FROM portman_test_results
GROUP BY test_type
ORDER BY test_type;

-- ============================================================================
-- STEP 5: Lag Selection Impact
-- ============================================================================

SELECT
    'Lag Selection Impact' as AnalysisType,
    max_lags,
    AVG(Q_statistic) as AvgQ_Statistic,
    AVG(p_value) as AvgP_Value,
    AVG(test_power) as AvgTestPower,
    AVG(sensitivity_score) as AvgSensitivity,
    SUM(autocorrelation_detected) as AutocorrDetections,
    COUNT(*) as TotalTests,
    CASE
        WHEN AVG(test_power) > 0.80 THEN 'High Power'
        WHEN AVG(test_power) > 0.70 THEN 'Adequate Power'
        ELSE 'Low Power'
    END as PowerAssessment
FROM portman_test_results
GROUP BY max_lags
ORDER BY max_lags;

-- ============================================================================
-- STEP 6: Confidence Level Sensitivity
-- ============================================================================

SELECT
    'Confidence Level Analysis' as AnalysisType,
    confidence_level,
    significance_threshold,
    COUNT(*) as TestCount,
    SUM(reject_null_hypothesis) as Rejections,
    CAST(SUM(reject_null_hypothesis) * 100.0 / COUNT(*) AS DECIMAL(6,2)) as RejectionRate,
    AVG(Q_statistic) as AvgQ_Statistic,
    AVG(critical_value) as AvgCriticalValue,
    AVG(Q_statistic - critical_value) as AvgQ_minus_Critical
FROM portman_test_results
GROUP BY confidence_level, significance_threshold
ORDER BY confidence_level DESC;

-- ============================================================================
-- STEP 7: Degrees of Freedom Adjustment Impact
-- ============================================================================

SELECT
    'DF Adjustment Impact' as AnalysisType,
    df_adjustment,
    max_lags,
    AVG(Q_statistic) as AvgQ_Statistic,
    AVG(critical_value) as AvgCriticalValue,
    AVG(p_value) as AvgP_Value,
    SUM(model_adequate) as ModelsAdequate,
    COUNT(*) as TotalTests,
    CAST(SUM(model_adequate) * 100.0 / COUNT(*) AS DECIMAL(6,2)) as ModelAdequacyRate
FROM portman_test_results
WHERE test_type = 'ljung_box'
GROUP BY df_adjustment, max_lags
ORDER BY df_adjustment, max_lags;

-- ============================================================================
-- STEP 8: Significant Lag Detection Analysis
-- ============================================================================

SELECT
    'Significant Lag Detection' as AnalysisType,
    test_config_id,
    max_lags,
    test_type,
    significant_lags,
    CAST(significant_lags * 100.0 / max_lags AS DECIMAL(6,2)) as SignificantLagPct,
    CAST(max_acf_value AS DECIMAL(6,4)) as MaxACF,
    max_acf_lag,
    CASE
        WHEN significant_lags = 0 THEN 'No Autocorrelation'
        WHEN significant_lags <= max_lags * 0.10 THEN 'Minimal Autocorrelation'
        WHEN significant_lags <= max_lags * 0.25 THEN 'Moderate Autocorrelation'
        ELSE 'Strong Autocorrelation'
    END as AutocorrelationAssessment
FROM portman_test_results
ORDER BY significant_lags DESC;

-- ============================================================================
-- STEP 9: Test Power and Sensitivity Analysis
-- ============================================================================

SELECT
    'Test Power Analysis' as AnalysisType,
    test_config_id,
    max_lags,
    confidence_level,
    test_type,
    CAST(test_power AS DECIMAL(6,4)) as TestPower,
    CAST(sensitivity_score AS DECIMAL(6,4)) as Sensitivity,
    CAST((test_power + sensitivity_score) / 2.0 AS DECIMAL(6,4)) as OverallEffectiveness,
    CASE
        WHEN test_power > 0.80 AND sensitivity_score > 0.75 THEN 'Excellent'
        WHEN test_power > 0.70 AND sensitivity_score > 0.65 THEN 'Good'
        WHEN test_power > 0.60 AND sensitivity_score > 0.55 THEN 'Adequate'
        ELSE 'Weak'
    END as DiagnosticCapability
FROM portman_test_results
ORDER BY (test_power + sensitivity_score) DESC;

-- ============================================================================
-- STEP 10: Optimal Test Configuration Selection
-- ============================================================================

-- Calculate composite diagnostic score
DROP TABLE IF EXISTS portman_diagnostic_scores;
CREATE MULTISET TABLE portman_diagnostic_scores AS (
    SELECT
        test_config_id,
        test_type,
        max_lags,
        confidence_level,
        -- Normalize and weight components
        test_power * 0.35 as power_component,
        sensitivity_score * 0.30 as sensitivity_component,
        CAST(model_adequate AS DECIMAL(10,6)) * 0.20 as adequacy_component,
        (1.0 - CAST(significant_lags AS DECIMAL(10,6)) / NULLIFZERO(max_lags)) * 0.15 as specificity_component,
        -- Composite score
        test_power * 0.35 +
        sensitivity_score * 0.30 +
        CAST(model_adequate AS DECIMAL(10,6)) * 0.20 +
        (1.0 - CAST(significant_lags AS DECIMAL(10,6)) / NULLIFZERO(max_lags)) * 0.15 as diagnostic_quality_score
    FROM portman_test_results
) WITH DATA;

-- Top configurations
SELECT
    'Top Portmanteau Test Configurations' as ReportType,
    r.test_config_id,
    r.test_type,
    r.max_lags,
    r.confidence_level,
    r.df_adjustment,
    CAST(s.diagnostic_quality_score AS DECIMAL(6,4)) as QualityScore,
    CAST(r.test_power AS DECIMAL(6,4)) as TestPower,
    CAST(r.sensitivity_score AS DECIMAL(6,4)) as Sensitivity,
    r.model_adequate as ModelAdequate,
    RANK() OVER (ORDER BY s.diagnostic_quality_score DESC) as Rank
FROM portman_diagnostic_scores s
INNER JOIN portman_test_results r ON s.test_config_id = r.test_config_id
ORDER BY s.diagnostic_quality_score DESC
FETCH FIRST 10 ROWS ONLY;

-- Optimal configuration
SELECT
    'OPTIMAL PORTMANTEAU TEST CONFIGURATION' as ConfigType,
    r.test_type as RecommendedTestType,
    r.max_lags as RecommendedMaxLags,
    r.confidence_level as RecommendedConfidenceLevel,
    r.significance_threshold as RecommendedSignificanceThreshold,
    r.df_adjustment as RecommendedDF_Adjustment,
    CAST(s.diagnostic_quality_score AS DECIMAL(6,4)) as QualityScore,
    CAST(r.test_power AS DECIMAL(6,4)) as ExpectedTestPower,
    CAST(r.sensitivity_score AS DECIMAL(6,4)) as ExpectedSensitivity,
    CAST(r.critical_value AS DECIMAL(10,4)) as CriticalValue
FROM portman_diagnostic_scores s
INNER JOIN portman_test_results r ON s.test_config_id = r.test_config_id
ORDER BY s.diagnostic_quality_score DESC
FETCH FIRST 1 ROW ONLY;

-- Recommended by use case
SELECT
    'RECOMMENDED FOR CONSERVATIVE TESTING' as UseCase,
    test_type,
    max_lags,
    confidence_level,
    CAST(diagnostic_quality_score AS DECIMAL(6,4)) as Score
FROM portman_diagnostic_scores s
INNER JOIN portman_test_results r ON s.test_config_id = r.test_config_id
WHERE confidence_level >= 0.99
ORDER BY diagnostic_quality_score DESC
FETCH FIRST 1 ROW ONLY

UNION ALL

SELECT
    'RECOMMENDED FOR HIGH POWER' as UseCase,
    test_type,
    max_lags,
    confidence_level,
    CAST(diagnostic_quality_score AS DECIMAL(6,4)) as Score
FROM portman_diagnostic_scores s
INNER JOIN portman_test_results r ON s.test_config_id = r.test_config_id
WHERE r.test_power = (SELECT MAX(test_power) FROM portman_test_results)
FETCH FIRST 1 ROW ONLY

UNION ALL

SELECT
    'RECOMMENDED FOR GENERAL USE' as UseCase,
    test_type,
    max_lags,
    confidence_level,
    CAST(diagnostic_quality_score AS DECIMAL(6,4)) as Score
FROM portman_diagnostic_scores s
INNER JOIN portman_test_results r ON s.test_config_id = r.test_config_id
WHERE confidence_level = 0.950 AND max_lags IN (10, 20)
ORDER BY diagnostic_quality_score DESC
FETCH FIRST 1 ROW ONLY;

-- Export optimal configuration
DROP TABLE IF EXISTS optimal_portman_config;
CREATE MULTISET TABLE optimal_portman_config AS (
    SELECT
        r.*,
        s.diagnostic_quality_score,
        'PRODUCTION' as config_status,
        CURRENT_TIMESTAMP as config_timestamp
    FROM portman_diagnostic_scores s
    INNER JOIN portman_test_results r ON s.test_config_id = r.test_config_id
    ORDER BY s.diagnostic_quality_score DESC
    FETCH FIRST 1 ROW ONLY
) WITH DATA;

SELECT * FROM optimal_portman_config;

/*
PORTMANTEAU TEST OPTIMIZATION CHECKLIST:
□ Configure lag values (5, 10, 15, 20 or sqrt(n))
□ Set confidence levels (90%, 95%, 99%)
□ Adjust degrees of freedom for model parameters
□ Choose test type (Ljung-Box or Box-Pierce)
□ Evaluate test power and sensitivity
□ Assess detection of autocorrelation
□ Validate model adequacy decisions
□ Select optimal configuration

TEST TYPE CHARACTERISTICS:
1. Ljung-Box: More powerful in small samples, preferred
2. Box-Pierce: Simpler calculation, less powerful
3. Both test same null hypothesis (residuals are white noise)

LAG SELECTION GUIDELINES:
- Small samples (n < 100): Use min(10, n/5)
- Medium samples (100 ≤ n < 500): Use 10-20 lags
- Large samples (n ≥ 500): Use 20-30 lags
- Rule of thumb: sqrt(n) or ln(n)
- Test multiple lag values for robustness

DEGREES OF FREEDOM ADJUSTMENT:
- Subtract number of AR parameters
- Subtract number of MA parameters
- Example: ARIMA(1,0,1) has 2 parameters, df = h - 2
- Critical: Proper df adjustment prevents false rejections

DIAGNOSTIC QUALITY SCORE WEIGHTS:
- Test Power: 35% (ability to detect autocorrelation)
- Sensitivity: 30% (detection capability)
- Model Adequacy: 20% (correct classification)
- Specificity: 15% (avoiding false positives)

INTERPRETATION GUIDELINES:
- Reject H0 (p < α): Residuals show autocorrelation, model inadequate
- Fail to reject H0 (p ≥ α): Residuals consistent with white noise, model adequate
- Multiple significant ACF lags: Consider adding AR/MA terms
- Seasonal pattern in ACF: Consider seasonal model components

NEXT STEPS:
1. Review optimal test configuration
2. Validate on fitted model residuals
3. Interpret test results in context
4. Re-specify model if autocorrelation detected
5. Document diagnostic test results
6. Use optimal_portman_config in td_portman_workflow.sql
*/
