/* ============================================================================
   CUSTOMER SEGMENTATION & SALES ANALYSIS — RFM TECHNIQUE
   Dataset : sales_data_sample.csv  (2,823 order lines | 307 orders | 92 customers)
   Dialect : PostgreSQL (CTEs, NTILE, FILTER). Notes for SQL Server / MySQL
             equivalents are called out where syntax diverges.
   ============================================================================ */


/* ----------------------------------------------------------------------------
   0. DATA OVERVIEW
   ---------------------------------------------------------------------------- */

-- Row count, date range, and grain of the table
SELECT
    COUNT(*)                       AS line_items,
    COUNT(DISTINCT ORDERNUMBER)    AS orders,
    COUNT(DISTINCT CUSTOMERNAME)   AS customers,
    MIN(ORDERDATE)                 AS first_order,
    MAX(ORDERDATE)                 AS last_order
FROM sales_data_sample;

-- Distinct values worth knowing before trusting any aggregate
SELECT DISTINCT STATUS      FROM sales_data_sample;
SELECT DISTINCT YEAR_ID     FROM sales_data_sample ORDER BY 1;
SELECT DISTINCT PRODUCTLINE FROM sales_data_sample;
SELECT DISTINCT DEALSIZE    FROM sales_data_sample;
SELECT DISTINCT COUNTRY     FROM sales_data_sample ORDER BY 1;

-- IMPORTANT CAVEAT: 2005 is not a full year.
-- Confirm month coverage per year before comparing years head-to-head.
SELECT YEAR_ID, MIN(MONTH_ID) AS first_month, MAX(MONTH_ID) AS last_month,
       COUNT(DISTINCT MONTH_ID) AS months_present
FROM sales_data_sample
GROUP BY YEAR_ID
ORDER BY YEAR_ID;
-- 2003: months 1-12 (full)   2004: months 1-12 (full)   2005: months 1-5 only (partial)


/* ----------------------------------------------------------------------------
   1. REVENUE BREAKDOWNS
   ---------------------------------------------------------------------------- */

-- 1a. Revenue by product line
SELECT PRODUCTLINE, SUM(SALES) AS revenue, COUNT(DISTINCT ORDERNUMBER) AS orders
FROM sales_data_sample
GROUP BY PRODUCTLINE
ORDER BY revenue DESC;
-- Classic Cars leads ($3.92M), Vintage Cars second ($1.90M); Trains trail at $226K.

-- 1b. Revenue by year — read alongside the month-coverage check above
SELECT YEAR_ID, SUM(SALES) AS revenue
FROM sales_data_sample
GROUP BY YEAR_ID
ORDER BY YEAR_ID;
-- 2003: $3.52M | 2004: $4.72M | 2005: $1.79M (partial year — not a real decline)

-- 1c. Revenue by deal size
SELECT DEALSIZE, SUM(SALES) AS revenue, COUNT(*) AS line_items, AVG(SALES) AS avg_line_value
FROM sales_data_sample
GROUP BY DEALSIZE
ORDER BY revenue DESC;

-- 1d. Country leaderboard
SELECT COUNTRY, SUM(SALES) AS revenue
FROM sales_data_sample
GROUP BY COUNTRY
ORDER BY revenue DESC;
-- USA dominates ($3.63M) — more than 3x the next country, Spain ($1.22M).

-- 1e. Best-performing city within the USA
SELECT CITY, SUM(SALES) AS revenue
FROM sales_data_sample
WHERE COUNTRY = 'USA'
GROUP BY CITY
ORDER BY revenue DESC
LIMIT 5;
-- San Rafael leads ($655K), ahead of NYC ($561K).

-- 1f. Best product line within the USA
SELECT PRODUCTLINE, SUM(SALES) AS revenue
FROM sales_data_sample
WHERE COUNTRY = 'USA'
GROUP BY PRODUCTLINE
ORDER BY revenue DESC;
-- Classic Cars again leads domestically ($1.34M).

-- 1g. Seasonality: best month per (complete) year
SELECT YEAR_ID, MONTH_ID, SUM(SALES) AS revenue, COUNT(DISTINCT ORDERNUMBER) AS orders
FROM sales_data_sample
WHERE YEAR_ID IN (2003, 2004)        -- exclude 2005: partial year, not comparable
GROUP BY YEAR_ID, MONTH_ID
ORDER BY YEAR_ID, revenue DESC;
-- November is the strongest month in BOTH complete years — a real seasonal pattern,
-- not a one-off (2003: $1.03M, 2004: $1.09M), likely tied to holiday-season ordering.

-- 1h. What sells best in November specifically?
SELECT PRODUCTLINE, SUM(SALES) AS revenue, COUNT(DISTINCT ORDERNUMBER) AS orders
FROM sales_data_sample
WHERE MONTH_ID = 11 AND YEAR_ID IN (2003, 2004)
GROUP BY PRODUCTLINE
ORDER BY revenue DESC;


/* ----------------------------------------------------------------------------
   2. RFM CUSTOMER SEGMENTATION
   ---------------------------------------------------------------------------- */

-- 2a. Raw RFM inputs per customer
--     Recency  = days since each customer's last order, relative to the most
--                recent order date in the whole dataset (a fixed "today" anchor,
--                since this is historical data rather than a live system)
--     Frequency= number of distinct orders placed
--     Monetary = total revenue from that customer
WITH customer_orders AS (
    SELECT
        CUSTOMERNAME,
        COUNT(DISTINCT ORDERNUMBER)                                AS frequency,
        SUM(SALES)                                                  AS monetary,
        MAX(ORDERDATE)                                              AS last_order_date,
        (SELECT MAX(ORDERDATE) FROM sales_data_sample) - MAX(ORDERDATE) AS recency_days
        -- SQL Server equivalent: DATEDIFF(DAY, MAX(ORDERDATE), (SELECT MAX(ORDERDATE) FROM sales_data_sample))
    FROM sales_data_sample
    GROUP BY CUSTOMERNAME
),

-- 2b. Score each metric into quartiles (1 = worst, 4 = best)
--     Recency is inverted (ORDER BY recency_days DESC) so a SMALL number of days
--     since last order earns the HIGHEST score, matching frequency/monetary direction.
rfm_scored AS (
    SELECT
        *,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency ASC)      AS f_score,
        NTILE(4) OVER (ORDER BY monetary ASC)       AS m_score
    FROM customer_orders
)

SELECT
    CUSTOMERNAME,
    recency_days,
    frequency,
    ROUND(monetary::numeric, 2) AS monetary,
    r_score, f_score, m_score,
    (r_score + f_score + m_score) AS rfm_score,
    CONCAT(r_score, f_score, m_score) AS rfm_cell
FROM rfm_scored;

-- To persist this result for re-use in the steps below, materialize it as a table:
--   PostgreSQL : CREATE TEMP TABLE rfm AS <query above>;
--   SQL Server : SELECT ... INTO #rfm FROM rfm_scored;
--   MySQL      : CREATE TEMPORARY TABLE rfm AS <query above>;
-- The rest of this section assumes that table is named `rfm`.

/* 2c. WHY THE SEGMENT MAP MATTERS
   A 4x4x4 quartile scheme produces up to 64 possible RFM cells, but with only
   92 customers, the cells actually observed in this dataset don't cover every
   permutation — and a segmentation rule that only lists "nice round" cells
   (111, 444, 234...) will silently drop any customer whose cell isn't listed,
   sending them to NULL with no warning. This rewrite maps on R and F score
   RANGES instead of enumerating cells one by one, so every customer lands in
   exactly one segment — verified against this dataset's actual cell list. */

-- 2d. Segment assignment (range-based, not enumerated — see note above)
SELECT
    CUSTOMERNAME,
    rfm_cell,
    rfm_score,
    monetary,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'           -- bought recently, often, high spend
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'     -- consistent repeat buyers
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'       -- recent first/second purchase
        WHEN r_score = 3  AND f_score <= 2 THEN 'Promising'           -- recent, still building frequency
        WHEN r_score = 2  AND f_score >= 3 THEN 'At Risk'             -- used to buy often, gone quiet
        WHEN r_score = 2  AND f_score <= 2 THEN 'Needs Attention'     -- mid-recency, low frequency
        WHEN r_score <= 1 AND f_score >= 3 THEN 'Cant Lose Them'      -- big past spenders, long silence
        WHEN r_score <= 1 AND f_score <= 2 THEN 'Hibernating / Lost'  -- inactive, low engagement
    END AS segment
FROM rfm
ORDER BY rfm_score DESC;

-- 2e. Sanity check: confirm every customer received a segment (no NULLs)
WITH segmented AS (
    SELECT
        CASE
            WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
            WHEN r_score = 3  AND f_score <= 2 THEN 'Promising'
            WHEN r_score = 2  AND f_score >= 3 THEN 'At Risk'
            WHEN r_score = 2  AND f_score <= 2 THEN 'Needs Attention'
            WHEN r_score <= 1 AND f_score >= 3 THEN 'Cant Lose Them'
            WHEN r_score <= 1 AND f_score <= 2 THEN 'Hibernating / Lost'
        END AS segment
    FROM rfm
)
SELECT COUNT(*) AS unsegmented_customers FROM segmented WHERE segment IS NULL;
-- Expect 0. (The original cell-enumeration approach failed this check.)

-- 2f. Revenue contribution per segment — which customers actually drive revenue
WITH segmented AS (
    SELECT *,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
            WHEN r_score = 3  AND f_score <= 2 THEN 'Promising'
            WHEN r_score = 2  AND f_score >= 3 THEN 'At Risk'
            WHEN r_score = 2  AND f_score <= 2 THEN 'Needs Attention'
            WHEN r_score <= 1 AND f_score >= 3 THEN 'Cant Lose Them'
            WHEN r_score <= 1 AND f_score <= 2 THEN 'Hibernating / Lost'
        END AS segment
    FROM rfm
)
SELECT
    segment,
    COUNT(*)                          AS customers,
    SUM(monetary)                     AS total_revenue,
    ROUND(AVG(monetary)::numeric, 2)  AS avg_revenue_per_customer
FROM segmented
GROUP BY segment
ORDER BY total_revenue DESC;
-- Champions (11 customers) and Loyal Customers (24) together generate roughly
-- 60% of total revenue from under 40% of the customer base.


/* ----------------------------------------------------------------------------
   3. MARKET BASKET — WHAT GETS ORDERED TOGETHER
   ---------------------------------------------------------------------------- */

-- 3a. Reality check before reading too much into co-occurrence:
--     orders here average ~9 line items each, and ~70% of orders span more
--     than one product line. With that much overlap, almost any two popular
--     products will appear together at similar rates — so "products sold
--     together" is a weak signal on this dataset unless filtered to a
--     consistent order size, as below.
SELECT
    line_count,
    COUNT(*) AS orders_with_this_many_lines
FROM (
    SELECT ORDERNUMBER, COUNT(*) AS line_count
    FROM sales_data_sample
    GROUP BY ORDERNUMBER
) order_sizes
GROUP BY line_count
ORDER BY line_count;

-- 3b. Product codes appearing together, restricted to orders with exactly
--     3 line items (one consistent "basket size" for a fair comparison)
--     PostgreSQL: STRING_AGG. SQL Server: STUFF(...FOR XML PATH('')...). MySQL: GROUP_CONCAT.
WITH three_item_orders AS (
    SELECT ORDERNUMBER
    FROM sales_data_sample
    WHERE STATUS = 'Shipped'
    GROUP BY ORDERNUMBER
    HAVING COUNT(*) = 3
)
SELECT
    s.ORDERNUMBER,
    STRING_AGG(DISTINCT s.PRODUCTCODE, ', ' ORDER BY s.PRODUCTCODE) AS product_codes
FROM sales_data_sample s
WHERE s.ORDERNUMBER IN (SELECT ORDERNUMBER FROM three_item_orders)
GROUP BY s.ORDERNUMBER
ORDER BY s.ORDERNUMBER;


/* ============================================================================
   END OF FILE
   ============================================================================ */
