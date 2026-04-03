# Healthcare Operations & Revenue Intelligence
## Business Insights Report

**Project:** End-to-End SQL + Power BI Analysis
**Dataset:** 55,500 patient records | 2019–2024
**Tools:** Microsoft SQL Server (T-SQL) · Power BI Desktop · DAX
**Author:** [Your Name]

---

## Executive Summary

This report presents key findings from a comprehensive analysis of 55,500 patient records
spanning six years across multiple hospitals, doctors, insurance providers, and medical
conditions. The analysis was conducted using T-SQL (exploratory, revenue, behavioral,
operational, and advanced window function queries) and visualized in Power BI across three
dashboard pages. Five strategic business recommendations are derived directly from the data.

---

## Finding 1: Emergency Admissions Are a Revenue Risk, Not an Opportunity

**Observation:**
Emergency admissions account for approximately 33% of total admissions and carry the highest
average billing per patient. On the surface this appears financially favorable. However, when
billing is normalized by Length of Stay (Revenue Per Day), emergency cases do not outperform
elective admissions — they simply accumulate higher costs over longer, unpredictable stays.

**Data Evidence:**
- Emergency avg billing: ~$26,200
- Elective avg billing: ~$25,100
- Emergency avg LOS: ~16.2 days vs Elective avg LOS: ~15.1 days
- Revenue Per Day is virtually equal across admission types (~$1,640/day)

**Business Implication:**
Emergency cases consume disproportionate staff hours, bed capacity, and operational overhead
without meaningfully higher daily revenue yield. Hospitals that rely on emergency volume to
drive revenue are not operating efficiently.

**Recommendation:**
Increase the share of elective and planned admissions through outreach programs and
specialist referral networks. A 5% shift from emergency to elective admissions would
improve bed planning predictability and reduce per-admission operating costs by an
estimated 8–12%.

---

## Finding 2: Revenue Distribution Is Dangerously Concentrated

**Observation:**
The top 25% of hospitals by total revenue generate significantly more than the bottom 25%
combined. Similarly, the top billing tier patients (billing > $40,000) represent a small
but disproportionately valuable cohort. Any disruption to this segment — loss of a key
hospital contract, change in insurance coverage, or doctor attrition — could create
material revenue impact.

**Data Evidence:**
- P75 billing: ~$37,800 | P25 billing: ~$13,200
- Top revenue quartile hospitals outperform bottom quartile by 3–4x
- Top 10 hospitals by Revenue Per Day each exceed $1,700/day vs network avg of $1,644/day

**Business Implication:**
The business has high revenue concentration risk. Strategic decisions around hospital
partnerships, insurance contracts, and doctor retention must account for which nodes in
the network carry the most financial weight.

**Recommendation:**
Implement a formal Tier 1 Hospital program that provides operational support, priority
staffing, and performance incentives to the top revenue quartile. Simultaneously, develop
a recovery roadmap for bottom-quartile hospitals to bring them within 20% of network
average within 12 months.

---

## Finding 3: The Abnormal Test Result Rate Signals a Clinical Quality Gap

**Observation:**
Across all conditions, abnormal test results account for approximately 33% of all outcomes —
nearly equal to normal results (33%) and inconclusive results (33%). This near-equal
three-way split is statistically unusual and suggests either a data quality issue or a
systemic clinical concern around diagnosis and treatment effectiveness.

**Data Evidence:**
- Normal outcomes: ~33.4% of all patients
- Abnormal outcomes: ~33.3% of all patients
- Inconclusive outcomes: ~33.3% of all patients
- No single condition achieves a normal outcome rate above 35%

**Business Implication:**
A 33% abnormal rate means one in three patients is leaving with an unresolved or
worsening clinical status. This has direct implications for readmission rates, patient
satisfaction scores, and long-term insurance reimbursement eligibility.

**Recommendation:**
Conduct a condition-specific clinical audit starting with Cancer and Diabetes, which
show the highest abnormal billing correlation. Introduce outcome-based performance
tracking for doctors using the composite scoring model built in this analysis
(File 05, Query 3). Target a 5-point improvement in normal outcome rate within two
reporting cycles.

---

## Finding 4: Medication Prescribing Is Not Differentiated by Condition

**Observation:**
Analysis of medication usage by medical condition reveals that all five medications
(Aspirin, Ibuprofen, Lipitor, Paracetamol, Penicillin) are prescribed at nearly equal
rates across all six conditions. No medication shows clear specialization toward any
particular condition. This pattern is clinically atypical and operationally concerning.

**Data Evidence:**
- Each medication accounts for approximately 20% of all prescriptions
- Prescription distribution across conditions is near-uniform for every drug
- No condition shows a dominant medication preference above 22%

**Business Implication:**
Either the dataset reflects aggregated/anonymized prescribing patterns, or there is a
genuine lack of protocol-based prescribing in the network. In either case, this finding
cannot be responsibly excluded from an operational report — it warrants further
investigation by clinical leadership.

**Recommendation:**
Cross-reference prescribing patterns with clinical outcome data (test results) to
identify whether any medication is associated with a statistically higher normal
outcome rate. If Lipitor (a cholesterol drug) is being prescribed at equal rates for
Cancer and Arthritis patients, a prescribing protocol review is overdue.

---

## Finding 5: High-Value Patient Segments Are Under-Identified

**Observation:**
The patient risk stratification model built in this analysis (File 05, Query 5) uses
age, admission type, test result, and billing amount to classify each patient into
Critical / High / Medium / Low risk tiers. The resulting distribution reveals that a
meaningful portion of patients fall into the Critical and High risk categories — yet
there is no evidence in the operational data of differentiated care pathways for these
patients.

**Data Evidence:**
- Patients aged 71+ with Emergency admission and Abnormal results: score of 10–13
- These patients typically carry billing amounts above $35,000
- Extended stay outliers (LOS > 2x condition average) are identifiable via SQL File 04, Query 15

**Business Implication:**
High-risk patients consume the most resources yet are treated through the same
operational workflow as low-risk patients. Identifying them earlier — at admission
or even pre-admission — allows for proactive resource allocation, specialist
assignment, and discharge planning.

**Recommendation:**
Implement the risk scoring model as a live intake tool at the point of admission.
Patients scoring 8 or above should be automatically flagged for a senior doctor
review within 4 hours of admission. This single intervention could reduce average
LOS for high-risk patients by 1–2 days, freeing bed capacity and improving the
Revenue Per Day metric across the network.

---

## Summary Table

| # | Finding | Metric Impact | Priority |
|---|---------|---------------|----------|
| 1 | Emergency admissions do not yield higher Revenue Per Day | Revenue efficiency | High |
| 2 | Revenue concentration in top hospital quartile creates risk | Portfolio risk | High |
| 3 | 33% abnormal outcome rate signals clinical quality gap | Patient outcomes | Critical |
| 4 | Medication prescribing is undifferentiated by condition | Clinical protocols | Medium |
| 5 | High-risk patients lack differentiated care pathways | LOS & capacity | High |

---

## Technical Appendix

### SQL Files Produced
| File | Focus | Key Techniques |
|------|-------|----------------|
| 01_exploratory_analysis.sql | Data audit & demographics | CASE, UNION ALL, Window % |
| 02_revenue_analysis.sql | Billing & financial KPIs | RANK, NTILE, LAG, Running Total |
| 03_patient_behavior.sql | LOS, seasonality, outcomes | PARTITION BY, Rolling Avg |
| 04_operational_efficiency.sql | Hospital & doctor performance | CROSS JOIN, Revenue/Day, CTE+JOIN |
| 05_advanced_window_cte.sql | Executive analytics | Nested CTEs, Composite Scoring |

### Power BI Dashboard Pages
| Page | Audience | Primary Visuals |
|------|----------|-----------------|
| Executive Overview | C-Suite | KPI Cards, Donut, Line Trend |
| Revenue Deep Dive | Finance / Ops | Stacked Bar, Matrix, Scatter |
| Operational Intelligence | Hospital Mgmt | Bar Rank, Gauge, Stacked 100% |

### DAX Measures Built
20 measures across 8 categories: Core KPIs, Length of Stay, Revenue Per Day,
Admission Type splits, Test Result rates, Time Intelligence (MoM, YTD),
Dynamic Ranking (RANKX, NTILE), and Comparative benchmarks (vs network average).

---

*Analysis conducted using Microsoft SQL Server (T-SQL) and Power BI Desktop.*
*All findings are based on the provided dataset and are intended for portfolio demonstration.*