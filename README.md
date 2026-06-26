<div align="center">

<img src="https://readme-typing-svg.demolab.com/?font=Fira+Code&size=24&duration=3000&pause=1000&color=1D2B4F&center=true&vCenter=true&width=700&lines=Customer+Segmentation+%26+RFM+Analysis;Who+are+your+best+customers%2C+really%3F;SQL+%2B+Data-Driven+Retail+Insights" alt="Typing SVG" />

<p>
<img src="https://img.shields.io/badge/SQL-PostgreSQL-1D2B4F?style=for-the-badge&logo=postgresql&logoColor=white" />
<img src="https://img.shields.io/badge/Technique-RFM_Segmentation-C9A45C?style=for-the-badge" />
<img src="https://img.shields.io/badge/Customers-92-5B6B8C?style=for-the-badge" />
<img src="https://img.shields.io/badge/Revenue_Analyzed-%2410.03M-1D2B4F?style=for-the-badge" />
</p>

<sub>2,823 order lines · 307 orders · 92 customers · Jan 2003 – May 2005</sub>

</div>

<br>

> Every number on this page is recomputed directly from `sales_data_sample.csv`, and the SQL was test-executed before being committed — nothing here is copy-pasted narrative. This is a rewrite of an earlier version of the project; what changed and why is in [Methodology Notes](#-methodology-notes).

## 📁 Contents
- [`Customer_Segmentation.sql`](Customer_Segmentation.sql) — full annotated query set (PostgreSQL, with SQL Server / MySQL equivalents noted inline)
- `sales_data_sample.csv` — source data
- `charts/` — exported visuals referenced below

<br>

## 🧠 What is RFM?

RFM scores each customer on three dimensions of past purchase behavior:

| Metric | Meaning | In this dataset |
|---|---|---|
| **Recency** | Days since the customer's last order | Lower = more recently active |
| **Frequency** | Number of distinct orders placed | Higher = more engaged |
| **Monetary** | Total amount spent | Higher = more valuable |

Each metric is split into quartiles (1–4), and customers are grouped into segments based on where their Recency and Frequency scores land.

<br>

## 🎯 The Headline Number

<div align="center">

### Champions + Loyal Customers are **38%** of the customer base — and drive **55%** of all revenue.

</div>

That's the single most actionable insight here: retention spend aimed at this group has the highest leverage of anywhere in the customer base.

| Segment | Customers | % of Customers | Revenue | % of Revenue |
|---|---|---|---|---|
| 🏆 Champions | 11 | 12.0% | $2.85M | 28.4% |
| 💙 Loyal Customers | 24 | 26.1% | $2.66M | 26.5% |
| 💤 Hibernating / Lost | 22 | 23.9% | $1.49M | 14.9% |
| ⚠️ Needs Attention | 13 | 14.1% | $1.09M | 10.9% |
| 🔻 At Risk | 10 | 10.9% | $1.05M | 10.5% |
| 🌱 New Customers | 5 | 5.4% | $0.41M | 4.1% |
| ✨ Promising | 6 | 6.5% | $0.33M | 3.3% |
| 🆘 Can't Lose Them | 1 | 1.1% | $0.14M | 1.4% |

<p align="center"><img src="charts/revenue_by_segment.png" width="600" alt="Revenue contribution by segment"></p>

<br>

## 📊 Supporting Findings

<details open>
<summary><b>🌍 Geography & Product Mix</b></summary>
<br>

The USA generates $3.63M — more than 3x Spain, the next-highest country ($1.22M). Within the USA, San Rafael ($655K) edges out NYC ($561K) as the top city, and Classic Cars is the best-selling line domestically.

Classic Cars is the strongest product line overall ($3.92M), followed by Vintage Cars ($1.90M). Trains is the smallest line by a wide margin ($226K).

<p align="center"><img src="charts/revenue_by_productline.png" width="600" alt="Revenue by product line"></p>

</details>

<details open>
<summary><b>📅 Seasonality</b></summary>
<br>

November is the strongest sales month in **both** complete years in the data (2003: $1.03M, 2004: $1.09M) — a repeated pattern across two years, not a one-off.

> ⚠️ **2005 is excluded from year-over-year comparisons** because the dataset only covers January–May of that year. Treating it as a "down year" would be comparing 5 months against 12.

<p align="center"><img src="charts/monthly_seasonality.png" width="650" alt="Monthly seasonality"></p>

</details>

<details open>
<summary><b>🗺️ Segment Landscape</b></summary>
<br>

Plotting Recency against Frequency (bubble size = total spend) makes the gap between the two ends of the customer base visually obvious — a small cluster of high-frequency, recent, high-spend Champions in the upper left, and a long tail of Hibernating customers stretched out to the right.

<p align="center"><img src="charts/rfm_scatter.png" width="650" alt="RFM scatter"></p>
<p align="center"><img src="charts/segment_distribution.png" width="600" alt="Segment customer counts"></p>

</details>

<br>

## 🔍 Methodology Notes

<details>
<summary><b>Why the segment mapping changed from the original version</b></summary>
<br>

The original version of this project assigned segments by listing out specific 3-digit RFM cells (e.g. `111, 112, 121...` → "Lost Customer"). With 92 customers split into 4×4×4 = up to 64 possible cells, that approach only works if every cell a real customer can land in is explicitly listed. Checking against the actual cell distribution in this dataset showed multiple observed cells weren't covered by any rule — meaning some customers would have been silently assigned `NULL` with no error raised.

This rewrite maps segments using **ranges on Recency and Frequency scores** instead (e.g. `R≥3 AND F≥3 → Loyal Customers`), which by construction covers every possible score combination. A verification query (section `2e` in the SQL file) confirms **zero unsegmented customers** against this dataset.

</details>

<details>
<summary><b>Recency's reference point</b></summary>
<br>

Recency is calculated relative to the most recent order date *in the dataset* (May 31, 2005), not the actual current date — appropriate for historical data, but worth calling out explicitly since "today" is ambiguous otherwise.

</details>

<details>
<summary><b>Why "products bought together" is a weak signal here</b></summary>
<br>

Orders in this dataset average ~9 line items each, and about 70% of orders include more than one product line. With that much overlap, most popular products co-occur at similar rates regardless of any real affinity between them. The SQL file filters to orders with exactly 3 line items to get a fair, consistent comparison, but this should be read as illustrative rather than a strong basis for cross-sell decisions — a larger order-level dataset would be needed for that.

</details>

<br>

## 💡 Segment Definitions & Suggested Actions

| Segment | Profile | Suggested Action |
|---|---|---|
| 🏆 **Champions** | Recent, frequent, high spend | Protect this relationship — early access, loyalty recognition, direct account contact before they have a reason to look elsewhere |
| 💙 **Loyal Customers** | Reliable repeat buyers, slightly less recent/frequent than Champions | Keep the cadence going; usage-based loyalty perks |
| 🔻 **At Risk** | Used to buy often, haven't recently | Targeted win-back outreach before they're gone |
| ⚠️ **Needs Attention** | Mid-recency, low frequency | Identify the friction — feedback request, small incentive to re-engage |
| 🌱 **New Customers** | Recent first or second purchase | Onboarding follow-up, ensure first experience was good |
| ✨ **Promising** | Recent but still building frequency | Encourage a second/third purchase with a relevant offer |
| 🆘 **Can't Lose Them** | High past spend, long silence | High-touch, personal outreach — these were valuable customers |
| 💤 **Hibernating / Lost** | Inactive, low historical engagement | Lowest-cost reactivation only (broad email), or deprioritize |

<br>

## ▶️ Reproducing This Analysis

```sql
-- 1. Load sales_data_sample.csv into a table named sales_data_sample
-- 2. Run Customer_Segmentation.sql top to bottom — each section is independent
--    and commented with what it answers and what the result means
```

The SQL file is organized into four parts:
1. **Data overview & caveats** — row counts, date range, year completeness
2. **Revenue breakdowns** — product line, year, country, city, seasonality
3. **RFM scoring and segmentation** — with a built-in coverage check
4. **Market basket analysis** — with the line-count caveat above

<br>

<div align="center">
<sub>Built with SQL, verified with DuckDB, charted with matplotlib.</sub>
</div>
