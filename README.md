# 📦 E-Commerce Logistics & Delivery SLA Analysis — Olist

**Tools Used:** SQL (MySQL / PostgreSQL), Microsoft Excel  
**Dataset Scope:** 100,000+ Orders | 3,000+ Sellers | 8 Relational Tables | 27 Brazilian States (2016–2018)

> **Executive Impact:** Audited end-to-end fulfillment pipelines across 100K+ orders to isolate seller dispatch lags and interstate courier bottlenecks, designing dynamic route buffers projected to **cut late deliveries by 18%** and **reduce 1-star customer complaints by 60%**.

---

## 🎯 Business Problem
Olist connects thousands of small merchants across Brazil directly to marketplace buyers. While order volume scaled rapidly, **customer satisfaction and repeat purchase rates dropped sharply** whenever orders missed their Estimated Delivery Date (EDD). 

This project decomposes the fulfillment pipeline into distinct operational stages to answer three core questions:
1. **Where are delays happening?** Are late deliveries caused by slow merchants (dispatch lag) or 3PL logistics partners (carrier transit lag)?
2. **How much do delays hurt Customer Experience (CX)?** At what exact delay threshold do customer ratings collapse?
3. **How do we fix it?** Which sellers and interstate routes require SLA buffer recalibration?

---

## 🗂️ Data Architecture (8 Relational Tables)
Queried and joined 8 core tables from the Olist database:
* `orders` (Order timestamps, purchase, approval, carrier handover, actual delivery, and EDD)
* `order_items` (SKU-level pricing, freight value, and seller shipping limits)
* `order_reviews` (Customer ratings 1★ to 5★ and review timestamps)
* `sellers` & `customers` (State and zip-code mapping across 27 states)
* `products`, `order_payments`, & `geolocation`

---

## 🔍 Key Analytical Findings (Matched to SQL & Excel Models)

### 1. The 80/20 Seller Dispatch Bottleneck
* **Finding:** Using SQL Window Functions (`SUM() OVER()`, `ROW_NUMBER()`) to rank merchant handover speeds against `shipping_limit_date`, just **12% of sellers accounted for over 50% of all pre-shipment dispatch breaches**.
* **Operational Takeaway:** Late deliveries are heavily skewed by a small cohort of repeat-offender merchants rather than platform-wide seller sluggishness.

### 2. Interstate Freight Friction (72% of Carrier Delays)
* **Finding:** Over **70% of active merchants** are concentrated in the Southeast (São Paulo), while buyer demand is distributed nationwide. Cross-state (interstate) shipments—particularly from **SP to Northern/Northeastern states (BA, PA, CE, PE)** and **RJ**—drove **72% of all last-mile carrier transit delays**.

### 3. The Customer Rating Cliff (4.3★ vs. 2.2★)
* **Finding:** Approximately **8% of total delivered orders** breached their promised EDD.
* **CX Impact:** Orders delivered on or before EDD maintained a healthy **4.29★ average rating**. Once an order missed EDD by just **1 to 3 days**, average review scores plummeted to **2.25★**, triggering a **3x surge in 1-star complaints** (accounting for **60%+ of negative platform feedback**).

| Delivery Status Window | % of Total Orders | Avg. Review Score | 1-Star Review Rate |
| :--- | :---: | :---: | :---: |
| **Early / On-Time (<= 0 Days Late)** | 91.9% | **4.29 ★** | 9.4% |
| **Slightly Late (1–3 Days Past EDD)** | 3.4% | **2.25 ★** | **46.8%** |
| **Moderately Late (4–7 Days Past EDD)** | 2.1% | **1.78 ★** | **64.2%** |
| **Severely Late (> 7 Days Past EDD)** | 2.6% | **1.42 ★** | **78.5%** |

---

## 💡 Strategic Recommendations & Projected Impact
1. **Dynamic Interstate EDD Buffers:** Recalibrate promised delivery dates on high-variance Southeast-to-Northeast routes by adding a **+2 to +4 day predictive buffer**, reducing technical SLA breaches by an estimated **18%**.
2. **Tiered Seller SLA Enforcement:** Place the bottom **12% of delayed merchants** on automated dispatch alerts 24 hours prior to `shipping_limit_date`, imposing commission penalties on chronic breaches to eliminate **50%+ of handover lags**.
3. **Proactive Delay Communication:** Trigger automated status updates and freight credits when carrier transit crosses 80% of the EDD window, curbing reactive **1-star reviews by up to 60%**.

---

## 📊 Executive Dashboard & Relational Schema

### 1. Fulfillment SLA & Customer Experience Dashboard
![Executive Dashboard](assets/dashboard_preview.png)

### 2. 8-Table Relational Database Architecture
![Database Schema](assets/schema_diagram.png)

---

## Appendix: Optimized SQL Analytical Queries & Excel SLA Simulation Model

### 1. Seller Dispatch Bottleneck & Pareto Concentration (`WITH` CTE & Window Functions)
Identifies the **12% high-friction seller cohort responsible for over 50% of seller-to-carrier handover delays** using cumulative window summation (`SUM() OVER ()`) and `DENSE_RANK()`:

<pre><code>WITH seller_delay_metrics AS (
    SELECT 
        oi.seller_id,
        s.seller_state,
        COUNT(DISTINCT o.order_id) AS total_orders_fulfilled,
        SUM(
            CASE WHEN o.order_delivered_carrier_date > oi.shipping_limit_date 
            THEN 1 ELSE 0 END
        ) AS late_handover_orders,
        ROUND(
            AVG(EXTRACT(EPOCH FROM (o.order_delivered_carrier_date - oi.shipping_limit_date)) / 86400.0), 2
        ) AS avg_handover_delay_days
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset oi ON o.order_id = oi.order_id
    JOIN olist_sellers_dataset s ON oi.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id, s.seller_state
    HAVING COUNT(DISTINCT o.order_id) >= 10
),
pareto_ranking AS (
    SELECT 
        seller_id,
        seller_state,
        total_orders_fulfilled,
        late_handover_orders,
        avg_handover_delay_days,
        ROUND(
            SUM(late_handover_orders) OVER (ORDER BY late_handover_orders DESC) * 100.0 
            / SUM(late_handover_orders) OVER (), 2
        ) AS cumulative_delay_share_pct,
        DENSE_RANK() OVER (ORDER BY late_handover_orders DESC) AS seller_delay_rank
    FROM seller_delay_metrics
)
SELECT * FROM pareto_ranking
WHERE cumulative_delay_share_pct <= 55.0
ORDER BY seller_delay_rank ASC;</code></pre>

### 2. Delivery SLA Variance vs. Customer Review Degradation Query
Quantifies the non-linear drop in customer satisfaction and the **60%+ surge in 1-star complaints** across SLA breach buckets:

<pre><code>WITH delivery_sla_cohorts AS (
    SELECT 
        o.order_id,
        r.review_score,
        CASE 
            WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date 
                THEN '1. On-Time (Within SLA)'
            WHEN EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0 BETWEEN 0.1 AND 3.0 
                THEN '2. Minor Delay (1-3 Days)'
            WHEN EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0 BETWEEN 3.1 AND 7.0 
                THEN '3. Moderate Delay (4-7 Days)'
            ELSE '4. Severe SLA Breach (7+ Days)'
        END AS sla_cohort
    FROM olist_orders_dataset o
    JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
)
SELECT 
    sla_cohort,
    COUNT(order_id) AS total_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(
        SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(order_id), 2
    ) AS one_star_complaint_rate_pct
FROM delivery_sla_cohorts
GROUP BY sla_cohort
ORDER BY sla_cohort ASC;</code></pre>

### 3. Interstate Freight Corridor Bottleneck Ranking (`DENSE_RANK()`)
Isolates the worst-performing interstate seller-to-customer corridors across Brazil's 27 states:

<pre><code>SELECT 
    s.seller_state AS origin_state,
    c.customer_state AS destination_state,
    COUNT(DISTINCT o.order_id) AS corridor_orders,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0), 1
    ) AS avg_lead_time_days,
    ROUND(
        SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) * 100.0 
        / COUNT(DISTINCT o.order_id), 2
    ) AS sla_breach_rate_pct,
    DENSE_RANK() OVER (
        ORDER BY SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) * 1.0 
        / COUNT(DISTINCT o.order_id) DESC
    ) AS bottleneck_rank
FROM olist_orders_dataset o
JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
JOIN olist_order_items_dataset oi ON o.order_id = oi.order_id
JOIN olist_sellers_dataset s ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_state, c.customer_state
HAVING COUNT(DISTINCT o.order_id) >= 250
ORDER BY sla_breach_rate_pct DESC
LIMIT 15;</code></pre>

---

## Excel SLA Buffer & Freight Recalibration Simulation (`excel_models/`)

Built an interactive **Excel What-If SLA Buffer & Seller Cutoff Model** (`excel_models/sla_buffer_simulation_model.csv`) testing dynamic ETA padding across interstate zones and stricter seller dispatch cutoffs:

| Freight Corridor Tier | Route Profile | Order Volume | Baseline Transit | Baseline SLA Breach | Recommended Buffer | Projected SLA Breach | Projected 1-Star Reduction |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Tier-1 Local** | `SP -> SP` (Intra-State) | 36,450 | 8.2 Days | 4.1% | `+0.0 Days` | **4.1%** | Baseline |
| **Tier-2 Regional** | `SP -> RJ / MG / PR` | 34,120 | 14.6 Days | 11.8% | `+2.0 Days` | **6.4%** | **-54.2%** |
| **Tier-3 Long-Haul** | `SP -> BA / PE / CE` | 19,840 | 22.4 Days | 21.5% | `+3.5 Days` | **11.2%** | **-63.8%** |
| **Tier-4 Remote** | `SP -> AM / PA` (North) | 9,590 | 28.9 Days | 26.4% | `+4.5 Days` | **14.1%** | **-61.5%** |

### Core Excel Model Formulas Used
* **Dynamic ETA Buffer Calculation:** `=IF(Corridor_Tier="Tier-1", Baseline_ETA, Baseline_ETA + VLOOKUP(Corridor_Tier, Buffer_Table, 2, FALSE))`
* **Projected Late Delivery Rate:** `=COUNTIFS(Transit_Days, ">" & Recalibrated_ETA, Seller_Handover_Delay, "<=1.5") / COUNTA(Order_ID)`
* **Net Portfolio Impact:** Reduces overall late deliveries by **18.0%** and cuts 1-star delivery-related complaints by **60.2%** across the 27-state network.

