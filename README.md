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
