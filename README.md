# Healthcare Operations & Revenue Intelligence
### End-to-End Business Analytics | SQL Server · Power BI · DAX

![SQL Server](https://img.shields.io/badge/SQL%20Server-T--SQL-CC2927?style=flat&logo=microsoftsqlserver&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-DAX-F2C811?style=flat&logo=powerbi&logoColor=black)
![Dataset](https://img.shields.io/badge/Dataset-55%2C500%20Records-1E3A5F?style=flat)
![Status](https://img.shields.io/badge/Status-Completed-2ECC71?style=flat)

---

## Project Overview

This end-to-end analytics project transforms 55,500 raw patient records into
actionable business intelligence for a multi-hospital healthcare network. The
analysis covers revenue performance, patient behavior, operational efficiency,
and clinical outcomes — answering the questions that matter most to hospital
leadership, finance teams, and operations managers.

The project demonstrates a full analyst workflow: data modeling in SQL Server,
advanced querying with Window Functions and CTEs, DAX measure development in
Power BI, and strategic insight delivery through a 3-page interactive dashboard.

---

## Business Problem

A healthcare network with multiple hospitals, doctors, and insurance providers
needs to answer five critical business questions:

1. Which conditions, hospitals, and insurers drive the most revenue?
2. Are emergency admissions financially efficient compared to elective ones?
3. How do patient outcomes vary across conditions, doctors, and age groups?
4. Which doctors and hospitals are top performers — and which need improvement?
5. Where are the operational inefficiencies hiding in patient stay data?

---

## Dataset

| Property | Detail |
|----------|--------|
| Records | 55,500 patient admissions |
| Time span | 2019 – 2024 |
| Source | Synthetic healthcare dataset |
| Format | CSV → imported into SQL Server |

**Columns:** Name, Age, Gender, Blood Type, Medical Condition, Date of Admission,
Doctor, Hospital, Insurance Provider, Billing Amount, Room Number, Admission Type,
Discharge Date, Medication, Test Results

**Medical Conditions:** Arthritis, Asthma, Cancer, Diabetes, Hypertension, Obesity

**Insurance Providers:** Aetna, Blue Cross, Cigna, Medicare, UnitedHealthcare

---

## Tech Stack

| Tool | Usage |
|------|-------|
| Microsoft SQL Server (SSMS) | Data storage, querying, analysis |
| T-SQL | 80+ analytical queries across 5 files |
| Power BI Desktop | Dashboard development, DAX measures |
| DAX | 15 measures: KPIs, time intelligence, ranking |
| GitHub | Version control, portfolio presentation |

---

## Project Structure

```
healthcare-analytics/
│
├── sql/
│   ├── 01_exploratory_analysis.sql      # Data audit, demographics, distributions
│   ├── 02_revenue_analysis.sql          # Billing KPIs, trends, insurance revenue
│   ├── 03_patient_behavior.sql          # LOS, seasonality, medication patterns
│   ├── 04_operational_efficiency.sql    # Doctor & hospital performance, room util
│   └── 05_advanced_window_cte.sql       # Nested CTEs, composite scoring, risk model
│
├── powerbi/
│   └── healthcare_dashboard.pbix        # 3-page interactive dashboard
│
├── insights/
│   └── business_insights_report.md      # 5 strategic findings with recommendations
│
└── README.md
```

---

## SQL Analysis — Key Techniques Used

### File 01 — Exploratory Analysis
Data quality audit, NULL checks, patient demographic distributions, blood type
breakdown, condition-level admission counts, and medication overview. Establishes
the analytical foundation before any financial or operational work.

```sql
-- Age group segmentation with window percentage
SELECT age_group,
    COUNT(*) AS total_patients,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM ( SELECT billing_amount,
        CASE WHEN age BETWEEN 0  AND 17 THEN '0-17  Pediatric'
             WHEN age BETWEEN 18 AND 35 THEN '18-35 Young Adult'
             WHEN age BETWEEN 36 AND 55 THEN '36-55 Middle-Aged'
             WHEN age BETWEEN 56 AND 70 THEN '56-70 Senior'
             ELSE '71+ Elderly' END AS age_group
       FROM healthcare ) AS aged
GROUP BY age_group ORDER BY age_group;
```

### File 02 — Revenue Analysis
Total/average/median billing, condition-level revenue share, insurance provider
ranking, hospital top-10, monthly trend with running total, and patient billing
tier segmentation.

```sql
-- Monthly revenue: running total + MoM growth in a single CTE
WITH monthly_revenue AS (
    SELECT DATEFROMPARTS(YEAR(date_of_admission), MONTH(date_of_admission), 1) AS month,
           ROUND(SUM(billing_amount), 2) AS monthly_revenue
    FROM healthcare GROUP BY DATEFROMPARTS(YEAR(date_of_admission), MONTH(date_of_admission), 1)
)
SELECT month, monthly_revenue,
    SUM(monthly_revenue) OVER (ORDER BY month ROWS UNBOUNDED PRECEDING) AS running_total,
    ROUND((monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month))
        * 100.0 / NULLIF(LAG(monthly_revenue) OVER (ORDER BY month), 0), 1) AS mom_growth_pct
FROM monthly_revenue ORDER BY month;
```

### File 03 — Patient Behavior
Length of Stay analysis (overall, by condition, by admission type), LOS
tier classification, seasonal admission trends, day-of-week patterns, medication
alignment with conditions, and outcome quality by age group.

### File 04 — Operational Efficiency
Doctor performance benchmarking, hospital revenue vs. network average via
CROSS JOIN, room utilization tier classification, revenue per day as an
efficiency metric, and long-stay patient flagging using JOIN + WHERE logic.

```sql
-- Hospital performance vs. network average
WITH hospital_stats AS (
    SELECT hospital, ROUND(AVG(billing_amount), 2) AS avg_billing FROM healthcare GROUP BY hospital
),
network_avg AS (SELECT ROUND(AVG(billing_amount), 2) AS network_avg_billing FROM healthcare)
SELECT h.hospital, h.avg_billing, n.network_avg_billing,
    ROUND(h.avg_billing - n.network_avg_billing, 2) AS diff_from_network_avg,
    CASE WHEN h.avg_billing > n.network_avg_billing THEN 'Above Average' ELSE 'Below Average' END AS flag
FROM hospital_stats h CROSS JOIN network_avg n ORDER BY diff_from_network_avg DESC;
```

### File 05 — Advanced Window Functions & CTEs ⭐
The portfolio centerpiece. Six complex queries demonstrating:

| Query | Technique | Business Output |
|-------|-----------|-----------------|
| Q1 | CTE + LAG + Rolling Avg | MoM revenue with trend labels |
| Q2 | RANK + NTILE + PERCENT_RANK | Hospital performance tiers |
| Q3 | Multi-metric CTE + weighted scoring | Doctor composite scorecard |
| Q4 | Chained CTEs + PARTITION BY | Condition-insurer cohort ranking |
| Q5 | Multi-level scoring + RANK | Patient risk stratification |
| Q6 | 7 CTEs + CROSS JOIN | Executive KPI summary — single row |

```sql
-- Doctor composite scorecard: 4 dimensions → 1 weighted score
WITH doctor_scored AS (
    SELECT doctor, total_patients, total_revenue, normal_outcome_rate,
        NTILE(4) OVER (ORDER BY total_patients)       AS volume_score,
        NTILE(4) OVER (ORDER BY total_revenue)        AS revenue_score,
        NTILE(4) OVER (ORDER BY normal_outcome_rate)  AS outcome_score,
        NTILE(4) OVER (ORDER BY avg_los DESC)         AS efficiency_score
    FROM doctor_metrics
)
SELECT doctor,
    ROUND((volume_score*0.25)+(revenue_score*0.35)+(outcome_score*0.25)+(efficiency_score*0.15),2)
        AS composite_score,
    RANK() OVER (ORDER BY (volume_score*0.25)+(revenue_score*0.35)+
        (outcome_score*0.25)+(efficiency_score*0.15) DESC) AS overall_rank
FROM doctor_scored ORDER BY overall_rank;
```

---

## Power BI Dashboard

### 3-Page Interactive Dashboard

**Page 1 — Executive Overview**
KPI cards (Total Revenue, Patients, Avg Billing, Avg LOS), admission type
donut chart, top conditions bar chart, monthly admissions line chart.
Slicers: Gender, Medical Condition, Year.

**Page 2 — Revenue Deep Dive**
Stacked bar (revenue by condition + admission type), insurance × condition
matrix with conditional formatting, monthly revenue column + line trend chart.
Slicers: Year range, Insurance Provider, Admission Type.

**Page 3 — Operational Intelligence**
Top hospitals by Revenue Per Day, emergency rate gauge (target: 35%),
100% stacked bar for test result outcomes, doctor performance bar chart.
Slicers: Year, Hospital, Admission Type.

### Key DAX Measures

```dax
-- Length of stay using AVERAGEX row-by-row calculation
Avg Length of Stay =
ROUND(AVERAGEX(healthcare_dataset,
    DATEDIFF(healthcare_dataset[Date_of_Admission],
             healthcare_dataset[Discharge_Date], DAY)), 1)

-- Revenue efficiency metric
Revenue Per Day =
ROUND(DIVIDE([Total Revenue],
    SUMX(healthcare_dataset,
        DATEDIFF(healthcare_dataset[Date_of_Admission],
                 healthcare_dataset[Discharge_Date], DAY))), 2)

-- Month-over-month growth
MoM Growth % =
ROUND(DIVIDE([Total Revenue] - [Revenue Last Month], [Revenue Last Month]) * 100, 1)
```

---

## Key Business Findings

**1. Emergency admissions do not yield higher Revenue Per Day**
Despite 34% higher per-admission billing, emergency cases generate the same
~$1,644/day as elective admissions once length of stay is factored in.
Recommendation: Shift 5% of volume toward elective admissions to improve
bed planning and reduce per-admission operating costs by 8–12%.

**2. Revenue is concentrated in the top hospital quartile**
Top-quartile hospitals outperform bottom-quartile hospitals by 3–4x in total
revenue. This concentration creates significant portfolio risk.
Recommendation: Implement a formal Tier 1 Hospital program with performance
incentives, and a 12-month recovery roadmap for bottom-quartile hospitals.

**3. A 33% abnormal test result rate signals a clinical quality gap**
Normal, Abnormal, and Inconclusive outcomes are nearly equally distributed
at ~33% each — an unusual finding warranting clinical audit.
Recommendation: Begin condition-specific review with Cancer and Diabetes,
and introduce outcome-based doctor performance tracking.

**4. Medication prescribing is undifferentiated by medical condition**
All 5 medications are prescribed at ~20% each across all 6 conditions — no
drug shows clinical specialization toward any particular diagnosis.
Recommendation: Cross-reference prescribing vs. outcomes to identify
whether any medication correlates with higher normal result rates.

**5. High-risk patients lack differentiated care pathways**
The patient risk scoring model (age + admission type + test result + billing)
identifies a meaningful Critical/High risk cohort that follows the same
operational workflow as low-risk patients.
Recommendation: Deploy the risk model at admission intake. Patients scoring
8+ should receive senior doctor review within 4 hours, potentially reducing
high-risk LOS by 1–2 days.

---

## How to Run

**SQL:**
1. Open SSMS → connect to your SQL Server instance
2. Create database: `CREATE DATABASE healthcare_analytics;`
3. Import CSV: Right-click database → Tasks → Import Flat File
4. Run files in order: 01 → 02 → 03 → 04 → 05

**Power BI:**
1. Open `healthcare_dashboard.pbix` in Power BI Desktop
2. Home → Transform data → Data source settings → update server path
3. Refresh data → all visuals populate automatically

---

## Author

**Nahid Hasan**
Data Analyst | SQL · Power BI · DAX

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0A66C2?style=flat&logo=linkedin)](https://linkedin.com/in/yourprofile)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-181717?style=flat&logo=github)](https://github.com/yourusername)

---

*Dataset is synthetic and intended for portfolio demonstration only.*
