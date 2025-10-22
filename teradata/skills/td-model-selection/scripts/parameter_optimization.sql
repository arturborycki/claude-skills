-- Parameter Optimization for TD_MODEL_SELECTION
-- Grid search and model comparison for UAF Model Preparation
-- Focus: Selection criteria (AIC/BIC/CV), model types, cross-validation folds

-- INSTRUCTIONS:
-- 1. Run uaf_data_preparation.sql first to prepare multi-model datasets
-- 2. Configure model candidate parameters
-- 3. Execute comprehensive model comparison
-- 4. Select best model based on validation performance

-- ============================================================================
-- STEP 1: Model Selection Parameter Grid
-- ============================================================================

DROP TABLE IF EXISTS model_selection_param_grid;
CREATE MULTISET TABLE model_selection_param_grid (
    config_id INTEGER,
    selection_criterion VARCHAR(50),
    cv_folds INTEGER,
    validation_method VARCHAR(50),
    complexity_penalty DECIMAL(5,3),
    min_sample_size INTEGER
);

INSERT INTO model_selection_param_grid VALUES
    -- AIC-based selection
    (1, 'AIC', 5, 'time_series_cv', 1.0, 50),
    (2, 'AIC', 10, 'time_series_cv', 1.0, 50),
    (3, 'AIC', 5, 'blocked_cv', 1.0, 50),

    -- BIC-based selection (stronger penalty)
    (4, 'BIC', 5, 'time_series_cv', 1.5, 50),
    (5, 'BIC', 10, 'time_series_cv', 1.5, 50),
    (6, 'BIC', 5, 'blocked_cv', 1.5, 50),

    -- Cross-validation error
    (7, 'CV_RMSE', 5, 'rolling_origin', 1.0, 50),
    (8, 'CV_RMSE', 10, 'rolling_origin', 1.0, 50),
    (9, 'CV_MAE', 5, 'rolling_origin', 1.0, 50),

    -- Adjusted R-squared
    (10, 'Adj_R_Squared', 5, 'time_series_cv', 1.2, 50),
    (11, 'Adj_R_Squared', 10, 'time_series_cv', 1.2, 50),

    -- Combined criteria
    (12, 'Composite', 5, 'time_series_cv', 1.0, 50),
    (13, 'Composite', 10, 'rolling_origin', 1.2, 50);

-- ============================================================================
-- STEP 2: Model Performance Comparison
-- ============================================================================

DROP TABLE IF EXISTS model_comparison_results;
CREATE MULTISET TABLE model_comparison_results (
    config_id INTEGER,
    model_id VARCHAR(50),
    model_type VARCHAR(100),
    selection_criterion VARCHAR(50),
    cv_folds INTEGER,
    -- Performance metrics
    aic DECIMAL(18,4),
    bic DECIMAL(18,4),
    cv_rmse DECIMAL(18,6),
    cv_mae DECIMAL(18,6),
    cv_mape DECIMAL(18,6),
    r_squared DECIMAL(18,6),
    adjusted_r_squared DECIMAL(18,6),
    -- Model properties
    n_parameters INTEGER,
    complexity_score INTEGER,
    training_time_sec DECIMAL(10,2),
    -- Selection metrics
    selection_score DECIMAL(18,6),
    rank_by_criterion INTEGER,
    created_timestamp TIMESTAMP
);

-- Populate with model candidates (from model_candidates table)
INSERT INTO model_comparison_results
SELECT
    p.config_id,
    m.model_id,
    m.model_type,
    p.selection_criterion,
    p.cv_folds,
    -- Simulated performance metrics (replace with actual UAF results)
    1000 + (m.parameter_count * 50) + (RANDOM() * 100) as aic,
    1050 + (m.parameter_count * 60) + (RANDOM() * 100) as bic,
    0.10 + (m.complexity_score * 0.02) + (RANDOM() * 0.05) as cv_rmse,
    0.08 + (m.complexity_score * 0.015) + (RANDOM() * 0.04) as cv_mae,
    8.0 + (m.complexity_score * 0.5) + (RANDOM() * 3.0) as cv_mape,
    0.85 - (m.complexity_score * 0.03) + (RANDOM() * 0.10) as r_squared,
    0.82 - (m.complexity_score * 0.03) + (RANDOM() * 0.10) as adjusted_r_squared,
    m.parameter_count,
    m.complexity_score,
    m.complexity_score * 10.0 + (RANDOM() * 20.0) as training_time_sec,
    0.0 as selection_score,  -- Calculated below
    0 as rank_by_criterion,
    CURRENT_TIMESTAMP
FROM model_selection_param_grid p
CROSS JOIN model_candidates m;

-- ============================================================================
-- STEP 3: Calculate Selection Scores
-- ============================================================================

-- Update selection scores based on criterion
UPDATE model_comparison_results
SET selection_score = CASE selection_criterion
    WHEN 'AIC' THEN -aic  -- Lower is better, so negate
    WHEN 'BIC' THEN -bic
    WHEN 'CV_RMSE' THEN -cv_rmse
    WHEN 'CV_MAE' THEN -cv_mae
    WHEN 'Adj_R_Squared' THEN adjusted_r_squared  -- Higher is better
    WHEN 'Composite' THEN (
        (-aic / 1000.0) * 0.25 +
        (-bic / 1000.0) * 0.25 +
        (-cv_rmse * 10.0) * 0.30 +
        (adjusted_r_squared) * 0.20
    )
    ELSE 0
END;

-- Calculate ranks within each configuration
UPDATE model_comparison_results
SET rank_by_criterion = (
    SELECT RANK() OVER (PARTITION BY config_id ORDER BY selection_score DESC)
    FROM model_comparison_results m2
    WHERE m2.config_id = model_comparison_results.config_id
    AND m2.model_id = model_comparison_results.model_id
);

-- ============================================================================
-- STEP 4: Best Model by Criterion
-- ============================================================================

SELECT
    'Best Model by Criterion' as ReportType,
    selection_criterion,
    cv_folds,
    model_id,
    model_type,
    CAST(aic AS DECIMAL(10,2)) as AIC,
    CAST(bic AS DECIMAL(10,2)) as BIC,
    CAST(cv_rmse AS DECIMAL(10,6)) as CV_RMSE,
    CAST(adjusted_r_squared AS DECIMAL(6,4)) as Adj_R2,
    n_parameters,
    CAST(selection_score AS DECIMAL(10,6)) as SelectionScore
FROM model_comparison_results
WHERE rank_by_criterion = 1
ORDER BY selection_criterion, cv_folds;

-- ============================================================================
-- STEP 5: Model Stability Across Configurations
-- ============================================================================

SELECT
    'Model Stability Analysis' as AnalysisType,
    model_id,
    model_type,
    COUNT(*) as TimesSelected,
    AVG(rank_by_criterion) as AvgRank,
    STDDEV(rank_by_criterion) as RankStdDev,
    AVG(cv_rmse) as AvgCV_RMSE,
    MIN(rank_by_criterion) as BestRank,
    CASE
        WHEN AVG(rank_by_criterion) <= 3 THEN 'Consistently Strong'
        WHEN AVG(rank_by_criterion) <= 5 THEN 'Moderately Strong'
        ELSE 'Weak'
    END as StabilityAssessment
FROM model_comparison_results
GROUP BY model_id, model_type
ORDER BY AvgRank ASC;

-- ============================================================================
-- STEP 6: Overfitting Analysis
-- ============================================================================

SELECT
    'Overfitting Risk Assessment' as AnalysisType,
    model_id,
    model_type,
    n_parameters,
    complexity_score,
    AVG(r_squared - adjusted_r_squared) as R2_Penalty,
    AVG(aic - bic) as AIC_BIC_Gap,
    CASE
        WHEN AVG(r_squared - adjusted_r_squared) > 0.05 THEN 'High Overfitting Risk'
        WHEN AVG(r_squared - adjusted_r_squared) > 0.02 THEN 'Moderate Risk'
        ELSE 'Low Risk'
    END as OverfittingRisk
FROM model_comparison_results
GROUP BY model_id, model_type, n_parameters, complexity_score
ORDER BY R2_Penalty DESC;

-- ============================================================================
-- STEP 7: Consensus Best Model
-- ============================================================================

-- Find model that performs best across multiple criteria
DROP TABLE IF EXISTS consensus_model_ranking;
CREATE MULTISET TABLE consensus_model_ranking AS (
    SELECT
        model_id,
        model_type,
        AVG(rank_by_criterion) as avg_rank,
        MIN(rank_by_criterion) as best_rank,
        MAX(rank_by_criterion) as worst_rank,
        STDDEV(rank_by_criterion) as rank_volatility,
        -- Consensus score (lower average rank is better)
        1.0 / (AVG(rank_by_criterion) + 1.0) as consensus_score,
        COUNT(CASE WHEN rank_by_criterion = 1 THEN 1 END) as times_ranked_first
    FROM model_comparison_results
    GROUP BY model_id, model_type
) WITH DATA;

-- ============================================================================
-- STEP 8: Optimal Model Selection
-- ============================================================================

SELECT
    'OPTIMAL MODEL SELECTION' as ReportType,
    c.model_id as SelectedModelID,
    c.model_type as SelectedModelType,
    CAST(c.consensus_score AS DECIMAL(6,4)) as ConsensusScore,
    c.times_ranked_first as TimesRankedFirst,
    CAST(c.avg_rank AS DECIMAL(6,2)) as AvgRank,
    -- Performance from best configuration
    CAST(AVG(m.aic) AS DECIMAL(10,2)) as AvgAIC,
    CAST(AVG(m.bic) AS DECIMAL(10,2)) as AvgBIC,
    CAST(AVG(m.cv_rmse) AS DECIMAL(10,6)) as AvgCV_RMSE,
    CAST(AVG(m.adjusted_r_squared) AS DECIMAL(6,4)) as AvgAdj_R2
FROM consensus_model_ranking c
INNER JOIN model_comparison_results m ON c.model_id = m.model_id
GROUP BY c.model_id, c.model_type, c.consensus_score, c.times_ranked_first, c.avg_rank
ORDER BY c.consensus_score DESC
FETCH FIRST 1 ROW ONLY;

-- Export optimal model configuration
DROP TABLE IF EXISTS optimal_model_selection;
CREATE MULTISET TABLE optimal_model_selection AS (
    SELECT
        c.model_id,
        c.model_type,
        c.consensus_score,
        'AIC' as recommended_criterion,  -- Most commonly used
        5 as recommended_cv_folds,
        'PRODUCTION' as config_status,
        CURRENT_TIMESTAMP as config_timestamp
    FROM consensus_model_ranking c
    ORDER BY c.consensus_score DESC
    FETCH FIRST 1 ROW ONLY
) WITH DATA;

SELECT * FROM optimal_model_selection;

/*
MODEL SELECTION OPTIMIZATION CHECKLIST:
□ Define comprehensive model candidate set
□ Configure selection criteria (AIC, BIC, CV)
□ Run cross-validation for all models
□ Compare models using multiple metrics
□ Assess overfitting risk
□ Evaluate model stability across criteria
□ Identify consensus best model
□ Validate on holdout test set
□ Document model selection rationale

SELECTION CRITERIA:
1. AIC (Akaike Information Criterion): -2*log(L) + 2*k
2. BIC (Bayesian Information Criterion): -2*log(L) + k*log(n)
3. CV Error: Cross-validated RMSE or MAE
4. Adjusted R²: R² penalized for number of parameters
5. Composite: Weighted combination of criteria

OVERFITTING INDICATORS:
- Large gap between R² and Adjusted R²
- High parameter count relative to data size
- Poor test set performance vs training
- High variance across CV folds

NEXT STEPS:
1. Review consensus model selection
2. Validate optimal model on test set
3. Check overfitting risk assessment
4. Apply selected model to production
5. Monitor model performance over time
6. Use optimal_model_selection in td_model_selection_workflow.sql
*/
