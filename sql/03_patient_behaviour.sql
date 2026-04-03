-- ============================================================
-- PROJECT  : Healthcare Operations & Revenue Intelligence
-- FILE     : 03_patient_behavior.sql
-- PURPOSE  : Analyze patient stay patterns, seasonal trends,
--            medication behavior, and outcome distributions.
-- AUTHOR   : [Your Name]
-- TOOL     : Microsoft SQL Server (T-SQL)
-- ============================================================

USE healthcare_analytics;
GO

-- ============================================================
-- SECTION 1: LENGTH OF STAY (LOS) ANALYSIS
-- Business Question: How long do patients stay, and what drives it?
-- ============================================================

-- Q1. Overall Length of Stay statistics
SELECT TOP 1
    MIN(DATEDIFF(DAY, date_of_admission, discharge_date))   OVER () AS min_los_days,
    MAX(DATEDIFF(DAY, date_of_admission, discharge_date))   OVER () AS max_los_days,
    ROUND(AVG(CAST(DATEDIFF(DAY, date_of_admission, discharge_date)
        AS FLOAT)) OVER (), 1)                                      AS avg_los_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP
        (ORDER BY DATEDIFF(DAY, date_of_admission, discharge_date))
        OVER ()                                                     AS median_los_days
FROM healthcare;

-- Q2. Average Length of Stay by medical condition
--     Which conditions require the longest hospital stays?
SELECT
    medical_condition,
    COUNT(*)                                                        AS total_patients,
    ROUND(AVG(CAST(
        DATEDIFF(DAY, date_of_admission, discharge_date)
    AS FLOAT)), 1)                                                  AS avg_los_days,
    MIN(DATEDIFF(DAY, date_of_admission, discharge_date))           AS min_los_days,
    MAX(DATEDIFF(DAY, date_of_admission, discharge_date))           AS max_los_days
FROM healthcare
GROUP BY medical_condition
ORDER BY avg_los_days DESC;

-- Q3. Average Length of Stay by admission type
--     Emergency vs Urgent vs Elective — who stays longer?
SELECT
    admission_type,
    COUNT(*)                                                        AS total_patients,
    ROUND(AVG(CAST(
        DATEDIFF(DAY, date_of_admission, discharge_date)
    AS FLOAT)), 1)                                                  AS avg_los_days,
    ROUND(SUM(CAST(
        DATEDIFF(DAY, date_of_admission, discharge_date)
    AS FLOAT)) / SUM(COUNT(*)) OVER (), 1)                          AS weighted_avg_contribution
FROM healthcare
GROUP BY admission_type
ORDER BY avg_los_days DESC;

-- Q4. LOS by medical condition AND admission type
--     Deep-dive: which combination has the longest stays?
SELECT
    medical_condition,
    admission_type,
    ROUND(AVG(CAST(
        DATEDIFF(DAY, date_of_admission, discharge_date)
    AS FLOAT)), 1)                                                  AS avg_los_days,
    COUNT(*)                                                        AS patient_count
FROM healthcare
GROUP BY medical_condition, admission_type
ORDER BY avg_los_days DESC;

-- Q5. LOS tier segmentation
--     Classifies every patient stay into short / medium / long
SELECT
    los_tier,
    COUNT(*)                                             AS patient_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct_of_total,
    ROUND(AVG(billing_amount), 2)                        AS avg_billing
FROM (
    SELECT
        billing_amount,
        CASE
            WHEN DATEDIFF(DAY, date_of_admission, discharge_date) <= 7
                THEN '1 | Short  (1-7 days)'
            WHEN DATEDIFF(DAY, date_of_admission, discharge_date) BETWEEN 8 AND 20
                THEN '2 | Medium (8-20 days)'
            ELSE
                '3 | Long   (21+ days)'
        END AS los_tier
    FROM healthcare
) AS tiered
GROUP BY los_tier
ORDER BY los_tier;


-- ============================================================
-- SECTION 2: SEASONAL ADMISSION TRENDS
-- Business Question: When do patients come in the most?
-- ============================================================

-- Q6. Monthly admission volume (all years combined)
--     Reveals seasonal peaks across the dataset
SELECT
    MONTH(date_of_admission)            AS month_number,
    DATENAME(MONTH, date_of_admission)  AS month_name,
    COUNT(*)                            AS total_admissions,
    ROUND(AVG(billing_amount), 2)       AS avg_billing
FROM healthcare
GROUP BY MONTH(date_of_admission), DATENAME(MONTH, date_of_admission)
ORDER BY month_number;

-- Q7. Quarterly admission trend
--     Summarizes seasonal patterns at a higher level
SELECT
    YEAR(date_of_admission)             AS admission_year,
    DATEPART(QUARTER, date_of_admission) AS quarter,
    COUNT(*)                            AS total_admissions,
    ROUND(SUM(billing_amount), 2)       AS total_revenue
FROM healthcare
GROUP BY YEAR(date_of_admission), DATEPART(QUARTER, date_of_admission)
ORDER BY admission_year, quarter;

-- Q8. Day of week admission pattern
--     Are more patients admitted on weekdays vs weekends?
SELECT
    DATEPART(WEEKDAY, date_of_admission)    AS day_number,
    DATENAME(WEEKDAY, date_of_admission)    AS day_name,
    COUNT(*)                                AS total_admissions,
    ROUND(AVG(billing_amount), 2)           AS avg_billing
FROM healthcare
GROUP BY DATEPART(WEEKDAY, date_of_admission), DATENAME(WEEKDAY, date_of_admission)
ORDER BY day_number;

-- Q9. Monthly admission trend per medical condition
--     Which condition spikes in which months?
SELECT
    medical_condition,
    DATENAME(MONTH, date_of_admission)      AS admission_month,
    MONTH(date_of_admission)                AS month_number,
    COUNT(*)                                AS total_admissions
FROM healthcare
GROUP BY medical_condition, DATENAME(MONTH, date_of_admission), MONTH(date_of_admission)
ORDER BY medical_condition, month_number;


-- ============================================================
-- SECTION 3: MEDICATION BEHAVIOR ANALYSIS
-- Business Question: How is medication aligned with diagnosis?
-- ============================================================

-- Q10. Most prescribed medication per medical condition
--      Uses RANK() to find #1 medication for each condition
WITH medication_rank AS (
    SELECT
        medical_condition,
        medication,
        COUNT(*)                                                    AS prescription_count,
        RANK() OVER (
            PARTITION BY medical_condition
            ORDER BY COUNT(*) DESC
        )                                                           AS rnk
    FROM healthcare
    GROUP BY medical_condition, medication
)
SELECT
    medical_condition,
    medication          AS top_medication,
    prescription_count
FROM medication_rank
WHERE rnk = 1
ORDER BY prescription_count DESC;

-- Q11. Medication vs. test result outcome
--      Does any medication correlate with better outcomes?
SELECT
    medication,
    COUNT(CASE WHEN test_results = 'Normal'       THEN 1 END)      AS normal_count,
    COUNT(CASE WHEN test_results = 'Abnormal'     THEN 1 END)      AS abnormal_count,
    COUNT(CASE WHEN test_results = 'Inconclusive' THEN 1 END)      AS inconclusive_count,
    COUNT(*)                                                        AS total_prescribed,
    ROUND(
        COUNT(CASE WHEN test_results = 'Normal' THEN 1 END) * 100.0
        / COUNT(*), 1
    )                                                               AS normal_outcome_rate_pct
FROM healthcare
GROUP BY medication
ORDER BY normal_outcome_rate_pct DESC;

-- Q12. Average billing by medication
--      Which medications are associated with higher-cost stays?
SELECT
    medication,
    COUNT(*)                        AS times_prescribed,
    ROUND(AVG(billing_amount), 2)   AS avg_billing,
    ROUND(SUM(billing_amount), 2)   AS total_billing
FROM healthcare
GROUP BY medication
ORDER BY avg_billing DESC;


-- ============================================================
-- SECTION 4: PATIENT OUTCOME ANALYSIS
-- Business Question: What patient profiles lead to abnormal results?
-- ============================================================

-- Q13. Test result distribution by age group
SELECT
    age_group,
    COUNT(CASE WHEN test_results = 'Normal'       THEN 1 END)      AS normal_count,
    COUNT(CASE WHEN test_results = 'Abnormal'     THEN 1 END)      AS abnormal_count,
    COUNT(CASE WHEN test_results = 'Inconclusive' THEN 1 END)      AS inconclusive_count,
    ROUND(
        COUNT(CASE WHEN test_results = 'Abnormal' THEN 1 END) * 100.0
        / COUNT(*), 1
    )                                                               AS abnormal_rate_pct
FROM (
    SELECT
        test_results,
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

-- Q14. Test result distribution by gender
SELECT
    gender,
    COUNT(CASE WHEN test_results = 'Normal'       THEN 1 END)      AS normal_count,
    COUNT(CASE WHEN test_results = 'Abnormal'     THEN 1 END)      AS abnormal_count,
    COUNT(CASE WHEN test_results = 'Inconclusive' THEN 1 END)      AS inconclusive_count,
    ROUND(
        COUNT(CASE WHEN test_results = 'Abnormal' THEN 1 END) * 100.0
        / COUNT(*), 1
    )                                                               AS abnormal_rate_pct
FROM healthcare
GROUP BY gender
ORDER BY abnormal_rate_pct DESC;

-- Q15. Billing by test result outcome
--      Do abnormal results lead to higher billing?
SELECT
    test_results,
    COUNT(*)                        AS patient_count,
    ROUND(AVG(billing_amount), 2)   AS avg_billing,
    ROUND(MIN(billing_amount), 2)   AS min_billing,
    ROUND(MAX(billing_amount), 2)   AS max_billing
FROM healthcare
GROUP BY test_results
ORDER BY avg_billing DESC;


-- ============================================================
-- SECTION 5: ADVANCED — PATIENT JOURNEY WITH WINDOW FUNCTIONS
-- Business Question: How do individual patient stays compare
--                   to the average for their condition?
-- ============================================================

-- Q16. Each patient's LOS vs. condition average
--      Flags patients who stayed significantly longer than peers
WITH patient_los AS (
    SELECT
        name,
        age,
        gender,
        medical_condition,
        admission_type,
        DATEDIFF(DAY, date_of_admission, discharge_date)            AS los_days,
        ROUND(AVG(CAST(DATEDIFF(DAY, date_of_admission, discharge_date)
            AS FLOAT)) OVER (PARTITION BY medical_condition), 1)    AS avg_los_for_condition
    FROM healthcare
)
SELECT
    name,
    age,
    medical_condition,
    admission_type,
    los_days,
    avg_los_for_condition,
    ROUND(los_days - avg_los_for_condition, 1)                      AS deviation_from_avg,
    CASE
        WHEN los_days > avg_los_for_condition * 1.5
            THEN 'High Risk — Extended Stay'
        WHEN los_days < avg_los_for_condition * 0.5
            THEN 'Fast Recovery'
        ELSE 'Typical Stay'
    END                                                             AS stay_classification
FROM patient_los
ORDER BY deviation_from_avg DESC;

-- Q17. Running patient count per month (admission momentum)
WITH monthly_admissions AS (
    SELECT
        DATEFROMPARTS(YEAR(date_of_admission), MONTH(date_of_admission), 1) AS admission_month,
        COUNT(*) AS monthly_count
    FROM healthcare
    GROUP BY DATEFROMPARTS(YEAR(date_of_admission), MONTH(date_of_admission), 1)
)
SELECT
    admission_month,
    monthly_count,
    SUM(monthly_count) OVER (
        ORDER BY admission_month
        ROWS UNBOUNDED PRECEDING
    )                                                               AS running_patient_total,
    ROUND(AVG(CAST(monthly_count AS FLOAT)) OVER (
        ORDER BY admission_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 0)                                                           AS rolling_3month_avg
FROM monthly_admissions
ORDER BY admission_month;

-- ============================================================
-- END OF FILE 03 — patient_behavior.sql
-- Next: 04_operational_efficiency.sql
-- ============================================================