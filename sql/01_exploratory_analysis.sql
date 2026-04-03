-- ============================================================
-- PROJECT  : Healthcare Operations & Revenue Intelligence
-- FILE     : 01_exploratory_analysis.sql
-- PURPOSE  : Understand the shape, distribution, and composition
--            of the dataset before any deeper analysis.
-- AUTHOR   : [Your Name]
-- TOOL     : Microsoft SQL Server (T-SQL)
-- ============================================================


-- ============================================================
-- SECTION 1: DATABASE SETUP
-- ============================================================

-- Step 1: Make sure you are in the right database
USE healthcare_analytics;
GO

-- Step 2: Create the table
CREATE TABLE healthcare (
    name               NVARCHAR(100),
    age                INT,
    gender             NVARCHAR(10),
    blood_type         NVARCHAR(5),
    medical_condition  NVARCHAR(50),
    date_of_admission  DATE,
    doctor             NVARCHAR(100),
    hospital           NVARCHAR(100),
    insurance_provider NVARCHAR(50),
    billing_amount     DECIMAL(12,2),
    room_number        INT,
    admission_type     NVARCHAR(20),
    discharge_date     DATE,
    medication         NVARCHAR(50),
    test_results       NVARCHAR(20)
);
GO

-- Step 3: Import CSV via SSMS
-- Right-click [healthcare_analytics] > Tasks > Import Flat File
-- Select your CSV, map columns, and finish.
-- OR use BULK INSERT (update path):
--
-- BULK INSERT healthcare
-- FROM 'E:\healthcare_analytics\healthcare_dataset.csv'
-- WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n');


-- ============================================================
-- SECTION 2: BASIC RECORD AUDIT
-- Business Question: Is our data complete and trustworthy?
-- ============================================================

-- Q1. Total number of patient records
SELECT COUNT(*) AS total_records
FROM healthcare;

-- Q2. Check for NULL values in critical columns
SELECT
    COUNT(CASE WHEN name               IS NULL THEN 1 END) AS null_name,
    COUNT(CASE WHEN age                IS NULL THEN 1 END) AS null_age,
    COUNT(CASE WHEN gender             IS NULL THEN 1 END) AS null_gender,
    COUNT(CASE WHEN medical_condition  IS NULL THEN 1 END) AS null_condition,
    COUNT(CASE WHEN billing_amount     IS NULL THEN 1 END) AS null_billing,
    COUNT(CASE WHEN date_of_admission  IS NULL THEN 1 END) AS null_admission_date,
    COUNT(CASE WHEN discharge_date     IS NULL THEN 1 END) AS null_discharge_date,
    COUNT(CASE WHEN insurance_provider IS NULL THEN 1 END) AS null_insurance
FROM healthcare;

-- Q3. Distinct value counts in key categorical columns
SELECT 'gender'             AS column_name, COUNT(DISTINCT gender)             AS distinct_values FROM healthcare
UNION ALL
SELECT 'medical_condition',                 COUNT(DISTINCT medical_condition)                     FROM healthcare
UNION ALL
SELECT 'admission_type',                    COUNT(DISTINCT admission_type)                        FROM healthcare
UNION ALL
SELECT 'insurance_provider',                COUNT(DISTINCT insurance_provider)                    FROM healthcare
UNION ALL
SELECT 'test_results',                      COUNT(DISTINCT test_results)                          FROM healthcare
UNION ALL
SELECT 'medication',                        COUNT(DISTINCT medication)                            FROM healthcare;


-- ============================================================
-- SECTION 3: PATIENT DEMOGRAPHICS
-- Business Question: Who are our patients?
-- ============================================================

-- Q4. Gender distribution with percentage
SELECT
    gender,
    COUNT(*)                                             AS total_patients,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct_of_total
FROM healthcare
GROUP BY gender
ORDER BY total_patients DESC;

-- Q5. Age group segmentation
SELECT
    age_group,
    COUNT(*)                                             AS total_patients,
    ROUND(AVG(billing_amount), 2)                        AS avg_billing,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct_of_total
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

-- Q6. Age statistics — min, max, average, median
SELECT TOP 1
    MIN(age)   OVER ()                                          AS youngest_patient,
    MAX(age)   OVER ()                                          AS oldest_patient,
    ROUND(AVG(CAST(age AS FLOAT)) OVER (), 1)                   AS avg_age,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY age) OVER ()    AS median_age
FROM healthcare;

-- Q7. Blood type distribution
SELECT
    blood_type,
    COUNT(*)                                             AS total_patients,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct_of_total
FROM healthcare
GROUP BY blood_type
ORDER BY total_patients DESC;


-- ============================================================
-- SECTION 4: MEDICAL CONDITION OVERVIEW
-- Business Question: What conditions drive the most admissions?
-- ============================================================

-- Q8. Admissions and average billing by medical condition
SELECT
    medical_condition,
    COUNT(*)                                             AS total_admissions,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct_share,
    ROUND(AVG(billing_amount), 2)                        AS avg_billing
FROM healthcare
GROUP BY medical_condition
ORDER BY total_admissions DESC;

-- Q9. Condition breakdown by gender
SELECT
    medical_condition,
    gender,
    COUNT(*) AS total_patients
FROM healthcare
GROUP BY medical_condition, gender
ORDER BY medical_condition, total_patients DESC;

-- Q10. Average patient age per medical condition
SELECT
    medical_condition,
    ROUND(AVG(CAST(age AS FLOAT)), 1)  AS avg_age,
    MIN(age)                           AS youngest,
    MAX(age)                           AS oldest
FROM healthcare
GROUP BY medical_condition
ORDER BY avg_age DESC;


-- ============================================================
-- SECTION 5: ADMISSION TYPE ANALYSIS
-- Business Question: How are patients entering our hospitals?
-- ============================================================

-- Q11. Admission type distribution
SELECT
    admission_type,
    COUNT(*)                                             AS total_admissions,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct_share,
    ROUND(AVG(billing_amount), 2)                        AS avg_billing
FROM healthcare
GROUP BY admission_type
ORDER BY total_admissions DESC;

-- Q12. Which conditions cause the most emergency admissions?
--      CASE WHEN inside COUNT() replaces PostgreSQL FILTER syntax
SELECT
    medical_condition,
    COUNT(CASE WHEN admission_type = 'Emergency' THEN 1 END)  AS emergency_count,
    COUNT(CASE WHEN admission_type = 'Urgent'    THEN 1 END)  AS urgent_count,
    COUNT(CASE WHEN admission_type = 'Elective'  THEN 1 END)  AS elective_count,
    COUNT(*)                                                  AS total
FROM healthcare
GROUP BY medical_condition
ORDER BY emergency_count DESC;


-- ============================================================
-- SECTION 6: TEST RESULTS OVERVIEW
-- Business Question: What do diagnostic outcomes look like?
-- ============================================================

-- Q13. Overall test result distribution
SELECT
    test_results,
    COUNT(*)                                             AS total,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct_share
FROM healthcare
GROUP BY test_results
ORDER BY total DESC;

-- Q14. Abnormal result rate by medical condition
SELECT
    medical_condition,
    COUNT(CASE WHEN test_results = 'Normal'       THEN 1 END)  AS normal_count,
    COUNT(CASE WHEN test_results = 'Abnormal'     THEN 1 END)  AS abnormal_count,
    COUNT(CASE WHEN test_results = 'Inconclusive' THEN 1 END)  AS inconclusive_count,
    ROUND(
        COUNT(CASE WHEN test_results = 'Abnormal' THEN 1 END) * 100.0
        / COUNT(*), 1
    )                                                          AS abnormal_rate_pct
FROM healthcare
GROUP BY medical_condition
ORDER BY abnormal_rate_pct DESC;


-- ============================================================
-- SECTION 7: MEDICATION OVERVIEW
-- Business Question: What medications are most prescribed?
-- ============================================================

-- Q15. Medication frequency ranking
SELECT
    medication,
    COUNT(*)                                             AS times_prescribed,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct_share
FROM healthcare
GROUP BY medication
ORDER BY times_prescribed DESC;

-- Q16. Medication usage by medical condition
SELECT
    medical_condition,
    medication,
    COUNT(*) AS prescription_count
FROM healthcare
GROUP BY medical_condition, medication
ORDER BY medical_condition, prescription_count DESC;


-- ============================================================
-- SECTION 8: DATASET DATE RANGE
-- Business Question: What time period does our data cover?
-- ============================================================

-- Q17. Admission date range
SELECT
    MIN(date_of_admission)                                    AS earliest_admission,
    MAX(date_of_admission)                                    AS latest_admission,
    DATEDIFF(DAY, MIN(date_of_admission), MAX(date_of_admission)) AS data_span_days
FROM healthcare;

-- Q18. Yearly admission volume trend
SELECT
    YEAR(date_of_admission)        AS admission_year,
    COUNT(*)                       AS total_admissions,
    ROUND(AVG(billing_amount), 2)  AS avg_billing
FROM healthcare
GROUP BY YEAR(date_of_admission)
ORDER BY admission_year;

-- ============================================================
-- END OF FILE 01 — exploratory_analysis.sql
-- Next: 02_revenue_analysis.sql
-- ============================================================