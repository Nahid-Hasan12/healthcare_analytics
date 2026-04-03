-- ============================================================
-- PROJECT  : Healthcare Operations & Revenue Intelligence
-- FILE     : 02_revenue_analysis.sql
-- PURPOSE  : Analyze billing patterns, revenue drivers, and
--            financial performance across conditions, hospitals,
--            and insurance providers.
-- AUTHOR   : [Your Name]
-- TOOL     : Microsoft SQL Server (T-SQL)
-- ============================================================

USE healthcare_analytics;
GO

-- ============================================================
-- SECTION 1: OVERALL REVENUE SNAPSHOT
-- Business Question: What does our financial baseline look like?
-- ============================================================

-- Q1. High-level revenue KPIs
SELECT TOP 1
    COUNT(*)         OVER ()                                        AS total_patients,
    SUM(billing_amount) OVER ()                                     AS total_revenue,
    ROUND(AVG(billing_amount) OVER (), 2)                           AS avg_billing_per_patient,
    ROUND(MIN(billing_amount) OVER (), 2)                           AS min_billing,
    ROUND(MAX(billing_amount) OVER (), 2)                           AS max_billing,
    ROUND(PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY billing_amount) OVER (), 2)          AS median_billing
FROM healthcare;


-- ============================================================
-- SECTION 2: BILLING BY MEDICAL CONDITION
-- Business Question: Which conditions generate the most revenue?
-- ============================================================

-- Q2. Revenue breakdown by medical condition
SELECT
    medical_condition,
    COUNT(*)                                                        AS total_patients,
    ROUND(SUM(billing_amount), 2)                                   AS total_revenue,
    ROUND(AVG(billing_amount), 2)                                   AS avg_billing,
    ROUND(SUM(billing_amount) * 100.0
        / SUM(SUM(billing_amount)) OVER (), 1)                      AS revenue_share_pct,
    RANK() OVER (ORDER BY SUM(billing_amount) DESC)                 AS revenue_rank
FROM healthcare
GROUP BY medical_condition
ORDER BY revenue_rank;

-- Q3. Billing spread (min, avg, max, range) per condition
--     Identifies conditions with high billing variance
SELECT
    medical_condition,
    ROUND(MIN(billing_amount), 2)                    AS min_billing,
    ROUND(AVG(billing_amount), 2)                    AS avg_billing,
    ROUND(MAX(billing_amount), 2)                    AS max_billing,
    ROUND(MAX(billing_amount) - MIN(billing_amount), 2) AS billing_range
FROM healthcare
GROUP BY medical_condition
ORDER BY billing_range DESC;


-- ============================================================
-- SECTION 3: BILLING BY ADMISSION TYPE
-- Business Question: Do emergency patients cost more?
-- ============================================================

-- Q4. Average billing and revenue per admission type
SELECT
    admission_type,
    COUNT(*)                          AS total_admissions,
    ROUND(AVG(billing_amount), 2)     AS avg_billing,
    ROUND(SUM(billing_amount), 2)     AS total_revenue
FROM healthcare
GROUP BY admission_type
ORDER BY avg_billing DESC;

-- Q5. Billing by admission type AND medical condition
SELECT
    admission_type,
    medical_condition,
    ROUND(AVG(billing_amount), 2)     AS avg_billing,
    COUNT(*)                          AS patient_count
FROM healthcare
GROUP BY admission_type, medical_condition
ORDER BY avg_billing DESC;


-- ============================================================
-- SECTION 4: INSURANCE PROVIDER REVENUE ANALYSIS
-- Business Question: Which insurer drives the most business?
-- ============================================================

-- Q6. Revenue and patient volume per insurance provider
SELECT
    insurance_provider,
    COUNT(*)                                                        AS total_patients,
    ROUND(SUM(billing_amount), 2)                                   AS total_revenue,
    ROUND(AVG(billing_amount), 2)                                   AS avg_billing,
    ROUND(SUM(billing_amount) * 100.0
        / SUM(SUM(billing_amount)) OVER (), 1)                      AS revenue_share_pct,
    RANK() OVER (ORDER BY SUM(billing_amount) DESC)                 AS revenue_rank
FROM healthcare
GROUP BY insurance_provider
ORDER BY revenue_rank;

-- Q7. Insurance provider vs. admission type
--     Which insurer handles the most emergency cases?
SELECT
    insurance_provider,
    COUNT(CASE WHEN admission_type = 'Emergency' THEN 1 END)        AS emergency_count,
    COUNT(CASE WHEN admission_type = 'Urgent'    THEN 1 END)        AS urgent_count,
    COUNT(CASE WHEN admission_type = 'Elective'  THEN 1 END)        AS elective_count,
    ROUND(AVG(billing_amount), 2)                                   AS avg_billing
FROM healthcare
GROUP BY insurance_provider
ORDER BY emergency_count DESC;


-- ============================================================
-- SECTION 5: HOSPITAL REVENUE PERFORMANCE
-- Business Question: Which hospitals are the top earners?
-- ============================================================

-- Q8. Top 10 hospitals by total revenue
SELECT TOP 10
    hospital,
    COUNT(*)                        AS total_patients,
    ROUND(SUM(billing_amount), 2)   AS total_revenue,
    ROUND(AVG(billing_amount), 2)   AS avg_billing_per_patient
FROM healthcare
GROUP BY hospital
ORDER BY total_revenue DESC;

-- Q9. Hospital revenue quartile ranking
--     Quartile 4 = top performers | Quartile 1 = lowest earners
SELECT
    hospital,
    ROUND(SUM(billing_amount), 2)                    AS total_revenue,
    NTILE(4) OVER (ORDER BY SUM(billing_amount))     AS revenue_quartile
FROM healthcare
GROUP BY hospital
ORDER BY total_revenue DESC;


-- ============================================================
-- SECTION 6: MONTHLY REVENUE TREND
-- Business Question: Is revenue growing over time?
-- ============================================================

-- Q10. Monthly revenue with running total and MoM growth
--      Uses CTE + LAG + SUM() OVER() — core window function showcase
WITH monthly_revenue AS (
    SELECT
        DATEFROMPARTS(YEAR(date_of_admission), MONTH(date_of_admission), 1) AS admission_month,
        COUNT(*)                                                             AS total_patients,
        ROUND(SUM(billing_amount), 2)                                        AS monthly_revenue
    FROM healthcare
    GROUP BY DATEFROMPARTS(YEAR(date_of_admission), MONTH(date_of_admission), 1)
)
SELECT
    admission_month,
    total_patients,
    monthly_revenue,
    ROUND(
        SUM(monthly_revenue) OVER (
            ORDER BY admission_month
            ROWS UNBOUNDED PRECEDING
        ), 2)                                                                AS running_total,
    ROUND(
        monthly_revenue
        - LAG(monthly_revenue) OVER (ORDER BY admission_month), 2)          AS mom_change,
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY admission_month))
        * 100.0
        / NULLIF(LAG(monthly_revenue) OVER (ORDER BY admission_month), 0), 1) AS mom_growth_pct
FROM monthly_revenue
ORDER BY admission_month;

-- Q11. Yearly revenue summary
SELECT
    YEAR(date_of_admission)          AS admission_year,
    COUNT(*)                         AS total_patients,
    ROUND(SUM(billing_amount), 2)    AS total_revenue,
    ROUND(AVG(billing_amount), 2)    AS avg_billing
FROM healthcare
GROUP BY YEAR(date_of_admission)
ORDER BY admission_year;


-- ============================================================
-- SECTION 7: BILLING PERCENTILE & TIER ANALYSIS
-- Business Question: How is revenue distributed across patients?
-- ============================================================

-- Q12. Billing percentiles (P25, P50, P75, P90, P95)
SELECT TOP 1
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY billing_amount) OVER (), 2) AS p25_billing,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY billing_amount) OVER (), 2) AS p50_billing,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY billing_amount) OVER (), 2) AS p75_billing,
    ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY billing_amount) OVER (), 2) AS p90_billing,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY billing_amount) OVER (), 2) AS p95_billing
FROM healthcare;

-- Q13. Patient billing tier segmentation
SELECT
    billing_tier,
    COUNT(*)                                             AS patient_count,
    ROUND(AVG(billing_amount), 2)                        AS avg_billing,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct_of_patients
FROM (
    SELECT
        billing_amount,
        CASE
            WHEN billing_amount < 15000                   THEN '1 | Low    (<15k)'
            WHEN billing_amount BETWEEN 15000 AND 35000   THEN '2 | Medium (15k-35k)'
            ELSE                                               '3 | High   (>35k)'
        END AS billing_tier
    FROM healthcare
) AS tiered
GROUP BY billing_tier
ORDER BY billing_tier;


-- ============================================================
-- SECTION 8: REVENUE BY AGE GROUP
-- Business Question: Which age segments generate the most revenue?
-- ============================================================

-- Q14. Revenue and patient volume by age group
SELECT
    age_group,
    COUNT(*)                        AS total_patients,
    ROUND(SUM(billing_amount), 2)   AS total_revenue,
    ROUND(AVG(billing_amount), 2)   AS avg_billing
FROM (
    SELECT
        billing_amount,
        CASE
            WHEN age BETWEEN 0  AND 17 THEN '1 | 0-17  Pediatric'
            WHEN age BETWEEN 18 AND 35 THEN '2 | 18-35 Young Adult'
            WHEN age BETWEEN 36 AND 55 THEN '3 | 36-55 Middle-Aged'
            WHEN age BETWEEN 56 AND 70 THEN '4 | 56-70 Senior'
            ELSE                             '5 | 71+   Elderly'
        END AS age_group
    FROM healthcare
) AS aged
GROUP BY age_group
ORDER BY age_group;

-- Q15. Top 20 highest-billing patients
SELECT TOP 20
    name,
    age,
    gender,
    medical_condition,
    insurance_provider,
    ROUND(billing_amount, 2)                         AS billing_amount,
    RANK() OVER (ORDER BY billing_amount DESC)       AS billing_rank
FROM healthcare
ORDER BY billing_amount DESC;

-- ============================================================
-- END OF FILE 02 — revenue_analysis.sql
-- Next: 03_patient_behavior.sql
-- ============================================================