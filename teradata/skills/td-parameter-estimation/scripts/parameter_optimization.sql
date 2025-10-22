-- Parameter Optimization for TD_PARAMETER_ESTIMATION
-- Grid search and hyperparameter tuning for UAF Model Preparation
-- Focus: Estimation methods, convergence criteria, confidence levels, iteration limits

-- INSTRUCTIONS:
-- 1. Run uaf_data_preparation.sql first to prepare train/test data
-- 2. Configure parameter grids for estimation algorithms
-- 3. Execute iterative parameter search
-- 4. Select optimal parameters based on estimation accuracy and stability

-- ============================================================================
-- STEP 1: Define Parameter Grid for Estimation
-- ============================================================================

-- Create comprehensive parameter grid
DROP TABLE IF EXISTS parameter_estimation_grid;
CREATE MULTISET TABLE parameter_estimation_grid (
    param_id INTEGER,
    estimation_method VARCHAR(50),
    confidence_level DECIMAL(5,3),
    max_iterations INTEGER,
    convergence_tolerance DECIMAL(10,8),
    optimizer VARCHAR(50),
    learning_rate DECIMAL(8,6),
    regularization_lambda DECIMAL(8,6)
);

-- Populate parameter combinations
INSERT INTO parameter_estimation_grid VALUES
    -- Maximum Likelihood Estimation (MLE)
    (1, 'MLE', 0.950, 100, 0.00001, 'newton_raphson', NULL, 0.0),
    (2, 'MLE', 0.950, 200, 0.000001, 'newton_raphson', NULL, 0.0),
    (3, 'MLE', 0.990, 100, 0.00001, 'bfgs', NULL, 0.0),
    (4, 'MLE', 0.990, 200, 0.000001, 'bfgs', NULL, 0.0),

    -- Least Squares Estimation
    (5, 'OLS', 0.950, 50, 0.0001, 'qr_decomposition', NULL, 0.0),
    (6, 'Ridge', 0.950, 100, 0.0001, 'gradient_descent', 0.01, 0.001),
    (7, 'Ridge', 0.950, 100, 0.0001, 'gradient_descent', 0.01, 0.01),
    (8, 'Ridge', 0.950, 100, 0.0001, 'gradient_descent', 0.01, 0.1),

    -- Method of Moments
    (9, 'MoM', 0.950, 50, 0.001, 'closed_form', NULL, 0.0),
    (10, 'MoM', 0.990, 50, 0.0001, 'closed_form', NULL, 0.0),

    -- Bayesian Estimation
    (11, 'Bayesian', 0.950, 500, 0.00001, 'mcmc', 0.001, 0.01),
    (12, 'Bayesian', 0.990, 1000, 0.000001, 'mcmc', 0.001, 0.01),

    -- Gradient-based Optimization
    (13, 'Gradient', 0.950, 200, 0.00001, 'adam', 0.001, 0.001),
    (14, 'Gradient', 0.950, 200, 0.00001, 'adam', 0.01, 0.01),
    (15, 'Gradient', 0.950, 300, 0.000001, 'sgd', 0.001, 0.001);

-- ============================================================================
-- STEP 2: Parameter Estimation Metrics Template
-- ============================================================================

-- Create results table
DROP TABLE IF EXISTS parameter_estimation_results;
CREATE MULTISET TABLE parameter_estimation_results (
    param_id INTEGER,
    estimation_method VARCHAR(50),
    confidence_level DECIMAL(5,3),
    max_iterations INTEGER,
    convergence_tolerance DECIMAL(10,8),
    optimizer VARCHAR(50),
    -- Estimated parameters
    estimated_alpha DECIMAL(18,8),
    estimated_beta DECIMAL(18,8),
    estimated_gamma DECIMAL(18,8),
    -- Confidence intervals
    alpha_ci_lower DECIMAL(18,8),
    alpha_ci_upper DECIMAL(18,8),
    beta_ci_lower DECIMAL(18,8),
    beta_ci_upper DECIMAL(18,8),
    -- Quality metrics
    log_likelihood DECIMAL(18,6),
    aic DECIMAL(18,6),
    bic DECIMAL(18,6),
    rmse_train DECIMAL(18,8),
    rmse_test DECIMAL(18,8),
    mae_train DECIMAL(18,8),
    mae_test DECIMAL(18,8),
    -- Convergence metrics
    iterations_used INTEGER,
    convergence_achieved INTEGER,
    estimation_time_sec DECIMAL(10,2),
    parameter_stability_score DECIMAL(10,6),
    created_timestamp TIMESTAMP
);

-- ============================================================================
-- STEP 3: Simulate Parameter Estimation for Each Configuration
-- ============================================================================

-- Initialize with sample estimates (replace with actual TD_PARAMETER_ESTIMATION calls)
INSERT INTO parameter_estimation_results
SELECT
    p.param_id,
    p.estimation_method,
    p.confidence_level,
    p.max_iterations,
    p.convergence_tolerance,
    p.optimizer,
    -- Simulated parameter estimates (replace with actual UAF function results)
    0.1 + (p.param_id * 0.01) as estimated_alpha,
    0.05 + (p.param_id * 0.005) as estimated_beta,
    0.02 + (p.param_id * 0.002) as estimated_gamma,
    -- Confidence intervals (simulated)
    (0.1 + (p.param_id * 0.01)) * (1 - 1.96 / SQRT(train_size)) as alpha_ci_lower,
    (0.1 + (p.param_id * 0.01)) * (1 + 1.96 / SQRT(train_size)) as alpha_ci_upper,
    (0.05 + (p.param_id * 0.005)) * (1 - 1.96 / SQRT(train_size)) as beta_ci_lower,
    (0.05 + (p.param_id * 0.005)) * (1 + 1.96 / SQRT(train_size)) as beta_ci_upper,
    -- Quality metrics (simulated - replace with actual model performance)
    -500.0 + (p.param_id * 5.0) as log_likelihood,
    1020.0 - (p.param_id * 2.0) as aic,
    1050.0 - (p.param_id * 2.0) as bic,
    0.15 - (p.param_id * 0.002) as rmse_train,
    0.18 - (p.param_id * 0.002) as rmse_test,
    0.12 - (p.param_id * 0.0015) as mae_train,
    0.14 - (p.param_id * 0.0015) as mae_test,
    -- Convergence
    CAST(p.max_iterations * 0.8 AS INTEGER) as iterations_used,
    1 as convergence_achieved,
    p.max_iterations * 0.05 as estimation_time_sec,
    0.95 - (p.param_id * 0.01) as parameter_stability_score,
    CURRENT_TIMESTAMP
FROM parameter_estimation_grid p
CROSS JOIN (SELECT COUNT(*) as train_size FROM uaf_parameter_ready) train_info;

-- ============================================================================
-- STEP 4: Estimation Accuracy Evaluation
-- ============================================================================

-- Evaluate estimation accuracy
SELECT
    'Estimation Accuracy' as MetricType,
    param_id,
    estimation_method,
    CAST(rmse_train AS DECIMAL(10,6)) as TrainRMSE,
    CAST(rmse_test AS DECIMAL(10,6)) as TestRMSE,
    CAST((rmse_test - rmse_train) AS DECIMAL(10,6)) as GeneralizationGap,
    CAST(mae_train AS DECIMAL(10,6)) as TrainMAE,
    CAST(mae_test AS DECIMAL(10,6)) as TestMAE,
    CASE
        WHEN rmse_test - rmse_train < 0.05 THEN 'Good Generalization'
        WHEN rmse_test - rmse_train < 0.10 THEN 'Moderate Generalization'
        ELSE 'Poor Generalization'
    END as GeneralizationAssessment
FROM parameter_estimation_results
ORDER BY rmse_test ASC;

-- ============================================================================
-- STEP 5: Convergence Analysis
-- ============================================================================

-- Analyze convergence behavior
SELECT
    'Convergence Analysis' as AnalysisType,
    estimation_method,
    optimizer,
    AVG(iterations_used) as AvgIterations,
    AVG(CAST(iterations_used AS DECIMAL(10,2)) / max_iterations) as AvgConvergenceRatio,
    SUM(convergence_achieved) as ConvergedCount,
    COUNT(*) as TotalRuns,
    AVG(estimation_time_sec) as AvgTimeSec
FROM parameter_estimation_results
GROUP BY estimation_method, optimizer
ORDER BY AvgTimeSec ASC;

-- ============================================================================
-- STEP 6: Information Criteria Comparison
-- ============================================================================

-- Compare models using AIC and BIC
SELECT
    'Model Selection Criteria' as MetricType,
    param_id,
    estimation_method,
    CAST(aic AS DECIMAL(10,2)) as AIC,
    CAST(bic AS DECIMAL(10,2)) as BIC,
    CAST(log_likelihood AS DECIMAL(10,2)) as LogLikelihood,
    RANK() OVER (ORDER BY aic ASC) as AIC_Rank,
    RANK() OVER (ORDER BY bic ASC) as BIC_Rank,
    CASE
        WHEN RANK() OVER (ORDER BY aic ASC) = RANK() OVER (ORDER BY bic ASC) THEN 'Consensus'
        ELSE 'Mixed'
    END as SelectionConsensus
FROM parameter_estimation_results
ORDER BY aic ASC;

-- ============================================================================
-- STEP 7: Confidence Interval Quality Assessment
-- ============================================================================

-- Evaluate confidence interval precision
SELECT
    'Confidence Interval Quality' as MetricType,
    param_id,
    confidence_level,
    -- Interval widths
    CAST(alpha_ci_upper - alpha_ci_lower AS DECIMAL(10,6)) as Alpha_CI_Width,
    CAST(beta_ci_upper - beta_ci_lower AS DECIMAL(10,6)) as Beta_CI_Width,
    -- Relative precision (narrower is better, but not too narrow)
    CAST((alpha_ci_upper - alpha_ci_lower) / NULLIFZERO(estimated_alpha) AS DECIMAL(10,6)) as Alpha_RelativePrecision,
    CAST((beta_ci_upper - beta_ci_lower) / NULLIFZERO(estimated_beta) AS DECIMAL(10,6)) as Beta_RelativePrecision
FROM parameter_estimation_results
ORDER BY Alpha_CI_Width ASC;

-- ============================================================================
-- STEP 8: Overall Optimization Score
-- ============================================================================

-- Calculate composite optimization score
DROP TABLE IF EXISTS parameter_optimization_scores;
CREATE MULTISET TABLE parameter_optimization_scores AS (
    SELECT
        param_id,
        estimation_method,
        -- Normalize metrics to 0-1 scale (lower is better)
        (1.0 - (rmse_test - min_rmse) / NULLIFZERO(max_rmse - min_rmse)) as rmse_score,
        (1.0 - (aic - min_aic) / NULLIFZERO(max_aic - min_aic)) as aic_score,
        (1.0 - (bic - min_bic) / NULLIFZERO(max_bic - min_bic)) as bic_score,
        (1.0 - (estimation_time_sec - min_time) / NULLIFZERO(max_time - min_time)) as time_score,
        parameter_stability_score as stability_score,
        -- Composite score (weighted average)
        (1.0 - (rmse_test - min_rmse) / NULLIFZERO(max_rmse - min_rmse)) * 0.35 +
        (1.0 - (aic - min_aic) / NULLIFZERO(max_aic - min_aic)) * 0.25 +
        (1.0 - (bic - min_bic) / NULLIFZERO(max_bic - min_bic)) * 0.20 +
        (1.0 - (estimation_time_sec - min_time) / NULLIFZERO(max_time - min_time)) * 0.10 +
        parameter_stability_score * 0.10 as total_optimization_score
    FROM parameter_estimation_results
    CROSS JOIN (
        SELECT
            MIN(rmse_test) as min_rmse, MAX(rmse_test) as max_rmse,
            MIN(aic) as min_aic, MAX(aic) as max_aic,
            MIN(bic) as min_bic, MAX(bic) as max_bic,
            MIN(estimation_time_sec) as min_time, MAX(estimation_time_sec) as max_time
        FROM parameter_estimation_results
    ) ranges
) WITH DATA;

-- ============================================================================
-- STEP 9: Optimal Parameter Selection
-- ============================================================================

-- Rank and display top configurations
SELECT
    'Top Parameter Configurations' as ReportType,
    p.param_id,
    r.estimation_method,
    r.confidence_level,
    r.optimizer,
    CAST(p.total_optimization_score AS DECIMAL(6,4)) as OptimizationScore,
    CAST(r.rmse_test AS DECIMAL(10,6)) as TestRMSE,
    CAST(r.aic AS DECIMAL(10,2)) as AIC,
    CAST(r.bic AS DECIMAL(10,2)) as BIC,
    r.iterations_used,
    CAST(r.estimation_time_sec AS DECIMAL(8,2)) as TimeSec,
    RANK() OVER (ORDER BY p.total_optimization_score DESC) as Rank
FROM parameter_optimization_scores p
INNER JOIN parameter_estimation_results r ON p.param_id = r.param_id
ORDER BY p.total_optimization_score DESC
FETCH FIRST 5 ROWS ONLY;

-- Best configuration
SELECT
    'OPTIMAL ESTIMATION CONFIGURATION' as ConfigType,
    r.estimation_method as RecommendedMethod,
    r.confidence_level as RecommendedConfidenceLevel,
    r.max_iterations as RecommendedMaxIterations,
    r.convergence_tolerance as RecommendedTolerance,
    r.optimizer as RecommendedOptimizer,
    CAST(p.total_optimization_score AS DECIMAL(6,4)) as QualityScore,
    CAST(r.rmse_test AS DECIMAL(10,6)) as ExpectedTestRMSE,
    CAST(r.aic AS DECIMAL(10,2)) as ExpectedAIC
FROM parameter_optimization_scores p
INNER JOIN parameter_estimation_results r ON p.param_id = r.param_id
ORDER BY p.total_optimization_score DESC
FETCH FIRST 1 ROW ONLY;

-- Export optimal configuration
DROP TABLE IF EXISTS optimal_estimation_config;
CREATE MULTISET TABLE optimal_estimation_config AS (
    SELECT
        r.*,
        p.total_optimization_score,
        'PRODUCTION' as config_status,
        CURRENT_TIMESTAMP as config_timestamp
    FROM parameter_optimization_scores p
    INNER JOIN parameter_estimation_results r ON p.param_id = r.param_id
    ORDER BY p.total_optimization_score DESC
    FETCH FIRST 1 ROW ONLY
) WITH DATA;

/*
PARAMETER ESTIMATION OPTIMIZATION CHECKLIST:
□ Define parameter grid for estimation algorithms
□ Configure confidence levels (90%, 95%, 99%)
□ Set convergence criteria and iteration limits
□ Test multiple optimizers (Newton-Raphson, BFGS, Adam, SGD)
□ Evaluate estimation accuracy (RMSE, MAE)
□ Compare information criteria (AIC, BIC)
□ Assess convergence behavior
□ Evaluate confidence interval quality
□ Select optimal configuration
□ Validate on test data

ESTIMATION METHODS:
1. Maximum Likelihood Estimation (MLE): Most common, asymptotically efficient
2. Ordinary Least Squares (OLS): Simple, assumes normality
3. Ridge Regression: Regularized, handles multicollinearity
4. Method of Moments (MoM): Simple, may be less efficient
5. Bayesian Estimation: Incorporates prior knowledge
6. Gradient-based: Flexible, works with complex models

OPTIMIZATION CRITERIA (WEIGHTS):
- Test RMSE: 35% (prediction accuracy)
- AIC: 25% (model fit with complexity penalty)
- BIC: 20% (stronger complexity penalty)
- Estimation Time: 10% (computational efficiency)
- Parameter Stability: 10% (estimation robustness)

NEXT STEPS:
1. Review optimization results and top configurations
2. Validate optimal parameters on holdout data
3. Check confidence interval coverage
4. Apply optimal configuration to production
5. Monitor parameter stability over time
6. Use optimal_estimation_config in td_parameter_estimation_workflow.sql
*/
