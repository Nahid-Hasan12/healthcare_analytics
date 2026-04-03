-- ============================================================
-- PROJECT  : Healthcare Operations & Revenue Intelligence
-- FILE     : 05_advanced_window_cte.sql
-- PURPOSE  : Demonstrate advanced analytical SQL — nested CTEs,
--            chained window functions, cohort analysis, and
--            executive-level KPI scoring. This file is the
--            centerpiece of the portfolio.
-- AUTHOR   : [Your Name]
-- TOOL     : Microsoft SQL Server (T-SQL)
-- ============================================================

USE healthcare_analytics;
GO

-- ============================================================
-- QUERY 1: MONTH-OVER-MONTH REVENUE WITH TREND CLASSIFICATION
-- Technique : CTE + LAG + CASE + Running Total
-- Business Q: Is revenue trending up or down each month?
-- ============================================================

WITH monthly_stats AS (
    SELECT
        DATEFROMPARTS(YEAR(date_of_admission), MONTH(date_of_admission), 1)  AS admission_month,
        COUNT(*)                                                              AS total_patients,
        ROUND(SUM(billing_amount), 2)                                         AS monthly_revenue
    FROM healthcare
    GROUP BY DATEFROMPARTS(YEAR(date_of_admission), MONTH(date_of_admission), 1)
),
mom_analysis AS (
    SELECT
        admission_month,
        total_patients,
        monthly_revenue,
        LAG(monthly_revenue)  OVER (ORDER BY admission_month)                AS prev_month_revenue,
        ROUND(monthly_revenue
            - LAG(monthly_revenue) OVER (ORDER BY admission_month), 2)       AS mom_change,
        ROUND(
            (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY admission_month))
            * 100.0
            / NULLIF(LAG(monthly_revenue) OVER (ORDER BY admission_month), 0)
        , 1)                                                                  AS mom_growth_pct,
        ROUND(SUM(monthly_revenue) OVER (
            ORDER BY admission_month
            ROWS UNBOUNDED PRECEDING
        ), 2)                                                                 AS cumulative_revenue,
        ROUND(AVG(CAST(monthly_revenue AS FLOAT)) OVER (
            ORDER BY admission_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2)                                                                 AS rolling_3m_avg
    FROM monthly_stats
)
SELECT
    admission_month,
    total_patients,
    monthly_revenue,
    prev_month_revenue,
    mom_change,
    mom_growth_pct,
    cumulative_revenue,
    rolling_3m_avg,
    CASE
        WHEN mom_growth_pct  > 5   THEN '? Strong Growth'
        WHEN mom_growth_pct  > 0   THEN '? Moderate Growth'
        WHEN mom_growth_pct  = 0   THEN '? Flat'
        WHEN mom_growth_pct IS NULL THEN '— Baseline'
        ELSE                            '? Decline'
    END                                                                       AS trend_label
FROM mom_analysis
ORDER BY admission_month;


-- ============================================================
-- QUERY 2: HOSPITAL REVENUE RANKING WITH PERCENTILE SCORING
-- Technique : Nested CTE + RANK + NTILE + PERCENT_RANK
-- Business Q: How does each hospital rank across the network?
-- ============================================================

WITH hospital_base AS (
    SELECT
        hospital,
        COUNT(*)                        AS total_patients,
        ROUND(SUM(billing_amount), 2)   AS total_revenue,
        ROUND(AVG(billing_amount), 2)   AS avg_billing,
        ROUND(AVG(CAST(
            DATEDIFF(DAY, date_of_admission, discharge_date)
        AS FLOAT)), 1)                  AS avg_los
    FROM healthcare
    GROUP BY hospital
),
hospital_ranked AS (
    SELECT
        hospital,
        total_patients,
        total_revenue,
        avg_billing,
        avg_los,
        RANK()         OVER (ORDER BY total_revenue   DESC)             AS revenue_rank,
        RANK()         OVER (ORDER BY total_patients  DESC)             AS volume_rank,
        NTILE(4)       OVER (ORDER BY total_revenue)                    AS revenue_quartile,
        ROUND(PERCENT_RANK() OVER (ORDER BY total_revenue) * 100, 1)   AS revenue_percentile
    FROM hospital_base
)
SELECT
    hospital,
    total_patients,
    total_revenue,
    avg_billing,
    avg_los,
    revenue_rank,
    volume_rank,
    revenue_quartile,
    revenue_percentile,
    CASE revenue_quartile
        WHEN 4 THEN 'Tier 1 — Top Performer'
        WHEN 3 THEN 'Tier 2 — Above Average'
        WHEN 2 THEN 'Tier 3 — Below Average'
        ELSE        'Tier 4 — Needs Improvement'
    END                                                                 AS performance_tier
FROM hospital_ranked
ORDER BY revenue_rank;


-- ============================================================
-- QUERY 3: DOCTOR PERFORMANCE SCORECARD
-- Technique : Multi-metric CTE + composite scoring
-- Business Q: Who are our best-performing doctors overall?
-- ============================================================

WITH doctor_metrics AS (
    SELECT
        doctor,
        COUNT(*)                                                        AS total_patients,
        ROUND(SUM(billing_amount), 2)                                   AS total_revenue,
        ROUND(AVG(billing_amount), 2)                                   AS avg_billing,
        ROUND(AVG(CAST(
            DATEDIFF(DAY, date_of_admission, discharge_date)
        AS FLOAT)), 1)                                                  AS avg_los,
        ROUND(
            COUNT(CASE WHEN test_results = 'Normal' THEN 1 END) * 100.0
            / COUNT(*), 1
        )                                                               AS normal_outcome_rate
    FROM healthcare
    GROUP BY doctor
),
doctor_scored AS (
    SELECT
        doctor,
        total_patients,
        total_revenue,
        avg_billing,
        avg_los,
        normal_outcome_rate,
        -- Each metric scored 1-4 using NTILE (4 = best)
        NTILE(4) OVER (ORDER BY total_patients)                         AS volume_score,
        NTILE(4) OVER (ORDER BY total_revenue)                          AS revenue_score,
        NTILE(4) OVER (ORDER BY normal_outcome_rate)                    AS outcome_score,
        -- Lower LOS is better, so reverse the order
        NTILE(4) OVER (ORDER BY avg_los DESC)                           AS efficiency_score
    FROM doctor_metrics
)
SELECT
    doctor,
    total_patients,
    total_revenue,
    avg_billing,
    avg_los,
    normal_outcome_rate,
    volume_score,
    revenue_score,
    outcome_score,
    efficiency_score,
    -- Composite score: weighted sum of all four dimensions
    ROUND(
        (volume_score * 0.25)
      + (revenue_score * 0.35)
      + (outcome_score * 0.25)
      + (efficiency_score * 0.15)
    , 2)                                                                AS composite_score,
    RANK() OVER (
        ORDER BY
            (volume_score * 0.25)
          + (revenue_score * 0.35)
          + (outcome_score * 0.25)
          + (efficiency_score * 0.15) DESC
    )                                                                   AS overall_rank
FROM doctor_scored
ORDER BY overall_rank;


-- ============================================================
-- QUERY 4: CONDITION-LEVEL COHORT REVENUE ANALYSIS
-- Technique : Chained CTEs + conditional aggregation + ranking
-- Business Q: Which condition-insurer combinations are most
--             valuable to the business?
-- ============================================================

WITH cohort_base AS (
    SELECT
        medical_condition,
        insurance_provider,
        admission_type,
        COUNT(*)                        AS patient_count,
        ROUND(SUM(billing_amount), 2)   AS total_revenue,
        ROUND(AVG(billing_amount), 2)   AS avg_billing,
        ROUND(AVG(CAST(
            DATEDIFF(DAY, date_of_admission, discharge_date)
        AS FLOAT)), 1)                  AS avg_los
    FROM healthcare
    GROUP BY medical_condition, insurance_provider, admission_type
),
cohort_ranked AS (
    SELECT
        medical_condition,
        insurance_provider,
        admission_type,
        patient_count,
        total_revenue,
        avg_billing,
        avg_los,
        RANK() OVER (
            PARTITION BY medical_condition
            ORDER BY total_revenue DESC
        )                               AS rank_within_condition,
        ROUND(total_revenue * 100.0
            / SUM(total_revenue) OVER (PARTITION BY medical_condition)
        , 1)                            AS pct_of_condition_revenue
    FROM cohort_base
)
SELECT
    medical_condition,
    insurance_provider,
    admission_type,
    patient_count,
    total_revenue,
    avg_billing,
    avg_los,
    rank_within_condition,
    pct_of_condition_revenue
FROM cohort_ranked
WHERE rank_within_condition <= 3          -- Top 3 combos per condition
ORDER BY medical_condition, rank_within_condition;


-- ============================================================
-- QUERY 5: PATIENT RISK STRATIFICATION
-- Technique : Multi-level CTE + CASE scoring + RANK
-- Business Q: Which patients are high-risk based on age,
--             condition severity, and billing amount?
-- ============================================================

WITH patient_scores AS (
    SELECT
        name,
        age,
        gender,
        medical_condition,
        admission_type,
        test_results,
        billing_amount,
        DATEDIFF(DAY, date_of_admission, discharge_date)    AS los_days,
        -- Age risk score
        CASE
            WHEN age >= 71 THEN 4
            WHEN age >= 56 THEN 3
            WHEN age >= 36 THEN 2
            ELSE 1
        END                                                 AS age_risk,
        -- Admission type risk score
        CASE admission_type
            WHEN 'Emergency' THEN 3
            WHEN 'Urgent'    THEN 2
            ELSE 1
        END                                                 AS admission_risk,
        -- Test result risk score
        CASE test_results
            WHEN 'Abnormal'     THEN 3
            WHEN 'Inconclusive' THEN 2
            ELSE 1
        END                                                 AS outcome_risk,
        -- Billing risk score (high billing = complex case)
        CASE
            WHEN billing_amount > 40000 THEN 3
            WHEN billing_amount > 20000 THEN 2
            ELSE 1
        END                                                 AS billing_risk
    FROM healthcare
),
risk_classified AS (
    SELECT
        name,
        age,
        gender,
        medical_condition,
        admission_type,
        test_results,
        billing_amount,
        los_days,
        age_risk,
        admission_risk,
        outcome_risk,
        billing_risk,
        (age_risk + admission_risk + outcome_risk + billing_risk)   AS total_risk_score,
        CASE
            WHEN (age_risk + admission_risk + outcome_risk + billing_risk) >= 11
                THEN '?? Critical Risk'
            WHEN (age_risk + admission_risk + outcome_risk + billing_risk) >= 8
                THEN '?? High Risk'
            WHEN (age_risk + admission_risk + outcome_risk + billing_risk) >= 5
                THEN '?? Medium Risk'
            ELSE
                '?? Low Risk'
        END                                                         AS risk_category
    FROM patient_scores
)
SELECT
    name,
    age,
    gender,
    medical_condition,
    admission_type,
    test_results,
    billing_amount,
    los_days,
    total_risk_score,
    risk_category,
    RANK() OVER (ORDER BY total_risk_score DESC)                    AS risk_rank
FROM risk_classified
ORDER BY total_risk_score DESC;


-- ============================================================
-- QUERY 6: EXECUTIVE SUMMARY DASHBOARD QUERY
-- Technique : Multiple CTEs unified into one result set
-- Business Q: Give leadership a single-view KPI snapshot
--             across all dimensions of the business.
-- ============================================================

WITH revenue_kpi AS (
    SELECT
        ROUND(SUM(billing_amount), 2)       AS total_revenue,
        COUNT(*)                            AS total_patients,
        ROUND(AVG(billing_amount), 2)       AS avg_billing
    FROM healthcare
),
los_kpi AS (
    SELECT
        ROUND(AVG(CAST(
            DATEDIFF(DAY, date_of_admission, discharge_date)
        AS FLOAT)), 1)                      AS avg_los_days
    FROM healthcare
),
top_condition AS (
    SELECT TOP 1
        medical_condition                   AS highest_revenue_condition
    FROM healthcare
    GROUP BY medical_condition
    ORDER BY SUM(billing_amount) DESC
),
top_hospital AS (
    SELECT TOP 1
        hospital                            AS highest_revenue_hospital
    FROM healthcare
    GROUP BY hospital
    ORDER BY SUM(billing_amount) DESC
),
top_insurer AS (
    SELECT TOP 1
        insurance_provider                  AS top_insurance_provider
    FROM healthcare
    GROUP BY insurance_provider
    ORDER BY COUNT(*) DESC
),
outcome_kpi AS (
    SELECT
        ROUND(
            COUNT(CASE WHEN test_results = 'Normal' THEN 1 END) * 100.0
            / COUNT(*), 1
        )                                   AS normal_outcome_rate_pct
    FROM healthcare
),
emergency_kpi AS (
    SELECT
        ROUND(
            COUNT(CASE WHEN admission_type = 'Emergency' THEN 1 END) * 100.0
            / COUNT(*), 1
        )                                   AS emergency_admission_rate_pct
    FROM healthcare
)
SELECT
    r.total_revenue,
    r.total_patients,
    r.avg_billing,
    l.avg_los_days,
    o.normal_outcome_rate_pct,
    e.emergency_admission_rate_pct,
    c.highest_revenue_condition,
    h.highest_revenue_hospital,
    i.top_insurance_provider
FROM revenue_kpi      r
CROSS JOIN los_kpi    l
CROSS JOIN outcome_kpi o
CROSS JOIN emergency_kpi e
CROSS JOIN top_condition c
CROSS JOIN top_hospital  h
CROSS JOIN top_insurer   i;

-- ============================================================
-- END OF FILE 05 — advanced_window_cte.sql
-- ============================================================
-- SQL ANALYSIS COMPLETE — 5 files | 80+ queries
-- Next step: Power BI Dashboard
-- ============================================================