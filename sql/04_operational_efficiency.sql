-- ============================================================
-- PROJECT  : Healthcare Operations & Revenue Intelligence
-- FILE     : 04_operational_efficiency.sql
-- PURPOSE  : Measure hospital and doctor-level performance,
--            room utilization, and discharge efficiency.
--            These insights directly support management decisions.
-- AUTHOR   : [Your Name]
-- TOOL     : Microsoft SQL Server (T-SQL)
-- ============================================================

USE healthcare_analytics;
GO

-- ============================================================
-- SECTION 1: DOCTOR PERFORMANCE ANALYSIS
-- Business Question: Which doctors handle the most patients
--                   and generate the most revenue?
-- ============================================================

-- Q1. Doctor-level patient volume and revenue summary
SELECT
    doctor,
    COUNT(*)                        AS total_patients,
    ROUND(SUM(billing_amount), 2)   AS total_revenue,
    ROUND(AVG(billing_amount), 2)   AS avg_billing_per_patient,
    ROUND(AVG(CAST(
        DATEDIFF(DAY, date_of_admission, discharge_date)
    AS FLOAT)), 1)                  AS avg_los_days
FROM healthcare
GROUP BY doctor
ORDER BY total_patients DESC;

-- Q2. Top 10 doctors by total revenue generated
SELECT TOP 10
    doctor,
    COUNT(*)                        AS total_patients,
    ROUND(SUM(billing_amount), 2)   AS total_revenue,
    ROUND(AVG(billing_amount), 2)   AS avg_billing
FROM healthcare
GROUP BY doctor
ORDER BY total_revenue DESC;

-- Q3. Doctor performance tier using NTILE
--     Segments doctors into 4 performance bands by patient volume
SELECT
    doctor,
    total_patients,
    total_revenue,
    avg_billing,
    NTILE(4) OVER (ORDER BY total_patients)         AS volume_quartile,
    NTILE(4) OVER (ORDER BY total_revenue)          AS revenue_quartile
    -- Quartile 4 = top tier | Quartile 1 = bottom tier
FROM (
    SELECT
        doctor,
        COUNT(*)                        AS total_patients,
        ROUND(SUM(billing_amount), 2)   AS total_revenue,
        ROUND(AVG(billing_amount), 2)   AS avg_billing
    FROM healthcare
    GROUP BY doctor
) AS doctor_summary
ORDER BY total_revenue DESC;

-- Q4. Doctor specialization — which condition does each doctor treat most?
WITH doctor_condition_rank AS (
    SELECT
        doctor,
        medical_condition,
        COUNT(*)                                            AS patient_count,
        RANK() OVER (
            PARTITION BY doctor
            ORDER BY COUNT(*) DESC
        )                                                   AS rnk
    FROM healthcare
    GROUP BY doctor, medical_condition
)
SELECT
    doctor,
    medical_condition       AS primary_specialization,
    patient_count
FROM doctor_condition_rank
WHERE rnk = 1
ORDER BY patient_count DESC;

-- Q5. Doctor outcome quality — normal result rate per doctor
--     Higher normal rate suggests better treatment outcomes
SELECT
    doctor,
    COUNT(*)                                                        AS total_patients,
    COUNT(CASE WHEN test_results = 'Normal'   THEN 1 END)          AS normal_results,
    COUNT(CASE WHEN test_results = 'Abnormal' THEN 1 END)          AS abnormal_results,
    ROUND(
        COUNT(CASE WHEN test_results = 'Normal' THEN 1 END) * 100.0
        / COUNT(*), 1
    )                                                               AS normal_outcome_rate_pct,
    RANK() OVER (
        ORDER BY
        COUNT(CASE WHEN test_results = 'Normal' THEN 1 END) * 100.0
        / COUNT(*) DESC
    )                                                               AS outcome_rank
FROM healthcare
GROUP BY doctor
ORDER BY outcome_rank;


-- ============================================================
-- SECTION 2: HOSPITAL PERFORMANCE ANALYSIS
-- Business Question: Which hospitals operate most efficiently?
-- ============================================================

-- Q6. Hospital-level operational summary
SELECT
    hospital,
    COUNT(*)                        AS total_patients,
    ROUND(SUM(billing_amount), 2)   AS total_revenue,
    ROUND(AVG(billing_amount), 2)   AS avg_billing,
    ROUND(AVG(CAST(
        DATEDIFF(DAY, date_of_admission, discharge_date)
    AS FLOAT)), 1)                  AS avg_los_days,
    COUNT(DISTINCT doctor)          AS total_doctors,
    COUNT(DISTINCT room_number)     AS rooms_used
FROM healthcare
GROUP BY hospital
ORDER BY total_revenue DESC;

-- Q7. Revenue per doctor per hospital
--     Measures doctor productivity at each hospital
SELECT
    hospital,
    COUNT(DISTINCT doctor)                                          AS doctor_count,
    ROUND(SUM(billing_amount), 2)                                   AS total_revenue,
    ROUND(SUM(billing_amount) / COUNT(DISTINCT doctor), 2)          AS revenue_per_doctor
FROM healthcare
GROUP BY hospital
ORDER BY revenue_per_doctor DESC;

-- Q8. Hospital admission type breakdown
--     Which hospitals handle the most emergency cases?
SELECT
    hospital,
    COUNT(CASE WHEN admission_type = 'Emergency' THEN 1 END)        AS emergency_count,
    COUNT(CASE WHEN admission_type = 'Urgent'    THEN 1 END)        AS urgent_count,
    COUNT(CASE WHEN admission_type = 'Elective'  THEN 1 END)        AS elective_count,
    COUNT(*)                                                        AS total_admissions,
    ROUND(
        COUNT(CASE WHEN admission_type = 'Emergency' THEN 1 END)
        * 100.0 / COUNT(*), 1
    )                                                               AS emergency_rate_pct
FROM healthcare
GROUP BY hospital
ORDER BY emergency_rate_pct DESC;

-- Q9. Hospital performance vs. network average
--     Shows which hospitals are above or below the avg billing
WITH hospital_stats AS (
    SELECT
        hospital,
        ROUND(AVG(billing_amount), 2)   AS avg_billing,
        COUNT(*)                        AS total_patients
    FROM healthcare
    GROUP BY hospital
),
network_avg AS (
    SELECT ROUND(AVG(billing_amount), 2) AS network_avg_billing
    FROM healthcare
)
SELECT
    h.hospital,
    h.total_patients,
    h.avg_billing,
    n.network_avg_billing,
    ROUND(h.avg_billing - n.network_avg_billing, 2)                 AS diff_from_network_avg,
    CASE
        WHEN h.avg_billing > n.network_avg_billing
            THEN 'Above Average'
        ELSE
            'Below Average'
    END                                                             AS performance_flag
FROM hospital_stats h
CROSS JOIN network_avg n
ORDER BY diff_from_network_avg DESC;


-- ============================================================
-- SECTION 3: ROOM UTILIZATION ANALYSIS
-- Business Question: How efficiently are rooms being used?
-- ============================================================

-- Q10. Room-level patient volume
--      Which rooms have the highest patient throughput?
SELECT TOP 20
    room_number,
    COUNT(*)                        AS total_patients,
    ROUND(AVG(billing_amount), 2)   AS avg_billing,
    ROUND(AVG(CAST(
        DATEDIFF(DAY, date_of_admission, discharge_date)
    AS FLOAT)), 1)                  AS avg_los_days
FROM healthcare
GROUP BY room_number
ORDER BY total_patients DESC;

-- Q11. Room utilization by medical condition
--      Identifies which conditions dominate specific rooms
SELECT
    room_number,
    medical_condition,
    COUNT(*)                        AS patient_count
FROM healthcare
GROUP BY room_number, medical_condition
ORDER BY room_number, patient_count DESC;

-- Q12. Room throughput tier classification
--      Labels rooms as High / Medium / Low utilization
SELECT
    utilization_tier,
    COUNT(*)                                             AS room_count,
    ROUND(AVG(avg_billing), 2)                           AS avg_billing_in_tier,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct_of_rooms
FROM (
    SELECT
        room_number,
        ROUND(AVG(billing_amount), 2)   AS avg_billing,
        CASE
            WHEN COUNT(*) >= 120  THEN '1 | High   Utilization'
            WHEN COUNT(*) BETWEEN 90 AND 119 THEN '2 | Medium Utilization'
            ELSE                             '3 | Low    Utilization'
        END                             AS utilization_tier
    FROM healthcare
    GROUP BY room_number
) AS room_tiers
GROUP BY utilization_tier
ORDER BY utilization_tier;


-- ============================================================
-- SECTION 4: DISCHARGE EFFICIENCY ANALYSIS
-- Business Question: How quickly are patients being discharged?
-- ============================================================

-- Q13. Average discharge turnaround by hospital
--      Shorter avg LOS with similar billing = higher efficiency
SELECT
    hospital,
    COUNT(*)                                                        AS total_patients,
    ROUND(AVG(CAST(
        DATEDIFF(DAY, date_of_admission, discharge_date)
    AS FLOAT)), 1)                                                  AS avg_los_days,
    ROUND(AVG(billing_amount), 2)                                   AS avg_billing,
    ROUND(
        AVG(billing_amount)
        / NULLIF(AVG(CAST(
            DATEDIFF(DAY, date_of_admission, discharge_date)
        AS FLOAT)), 0), 2
    )                                                               AS revenue_per_day
    -- Higher revenue_per_day = more efficient monetization per bed
FROM healthcare
GROUP BY hospital
ORDER BY revenue_per_day DESC;

-- Q14. Discharge efficiency by admission type
SELECT
    admission_type,
    ROUND(AVG(CAST(
        DATEDIFF(DAY, date_of_admission, discharge_date)
    AS FLOAT)), 1)                  AS avg_los_days,
    ROUND(AVG(billing_amount), 2)   AS avg_billing,
    ROUND(
        AVG(billing_amount)
        / NULLIF(AVG(CAST(
            DATEDIFF(DAY, date_of_admission, discharge_date)
        AS FLOAT)), 0), 2
    )                               AS revenue_per_day
FROM healthcare
GROUP BY admission_type
ORDER BY avg_los_days ASC;

-- Q15. Long-stay patient flag (potential inefficiency indicator)
--      Patients with LOS > 2x the average for their condition
WITH condition_avg AS (
    SELECT
        medical_condition,
        AVG(CAST(
            DATEDIFF(DAY, date_of_admission, discharge_date)
        AS FLOAT))                  AS avg_los
    FROM healthcare
    GROUP BY medical_condition
)
SELECT
    h.name,
    h.age,
    h.medical_condition,
    h.hospital,
    h.doctor,
    DATEDIFF(DAY, h.date_of_admission, h.discharge_date)    AS actual_los,
    ROUND(c.avg_los, 1)                                     AS condition_avg_los,
    ROUND(
        DATEDIFF(DAY, h.date_of_admission, h.discharge_date)
        - c.avg_los, 1
    )                                                       AS excess_days,
    h.billing_amount
FROM healthcare h
JOIN condition_avg c ON h.medical_condition = c.medical_condition
WHERE DATEDIFF(DAY, h.date_of_admission, h.discharge_date) > c.avg_los * 2
ORDER BY excess_days DESC;


-- ============================================================
-- SECTION 5: INSURANCE PROVIDER OPERATIONAL IMPACT
-- Business Question: Does insurance type affect LOS or outcomes?
-- ============================================================

-- Q16. LOS and billing by insurance provider
SELECT
    insurance_provider,
    COUNT(*)                                                        AS total_patients,
    ROUND(AVG(billing_amount), 2)                                   AS avg_billing,
    ROUND(AVG(CAST(
        DATEDIFF(DAY, date_of_admission, discharge_date)
    AS FLOAT)), 1)                                                  AS avg_los_days,
    ROUND(
        COUNT(CASE WHEN test_results = 'Normal' THEN 1 END) * 100.0
        / COUNT(*), 1
    )                                                               AS normal_outcome_rate_pct
FROM healthcare
GROUP BY insurance_provider
ORDER BY avg_billing DESC;

-- Q17. Insurance provider vs. hospital — patient volume matrix
--      Useful for contract and partnership decisions
SELECT
    insurance_provider,
    hospital,
    COUNT(*)                        AS patient_count,
    ROUND(SUM(billing_amount), 2)   AS total_billed
FROM healthcare
GROUP BY insurance_provider, hospital
ORDER BY insurance_provider, total_billed DESC;

-- ============================================================
-- END OF FILE 04 — operational_efficiency.sql
-- Next: 05_advanced_window_cte.sql  ? The showstopper file
-- ============================================================