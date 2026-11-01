/* ============================================================================
   PROJECT: Olist E-Commerce Logistics & Delivery SLA Analysis
   AUTHOR:  Shiv Kumar
   PURPOSE: Decompose order-to-delivery timelines, isolate seller vs. carrier
            bottlenecks, and quantify the CX impact of SLA breaches.
   ============================================================================ */

-- ----------------------------------------------------------------------------
-- QUERY 1: Stage-Gate Fulfillment Pipeline & Route Classification (CTE)
-- Separates Seller Dispatch Lag from 3PL Carrier Transit Lag across 100K+ orders
-- ----------------------------------------------------------------------------
WITH fulfillment_stages AS (
    SELECT 
        o.order_id,
        o.customer_id,
        oi.seller_id,
        c.customer_state,
        s.seller_state,
        CASE 
            WHEN c.customer_state = s.seller_state THEN 'Intrastate (Local)'
            ELSE 'Interstate (Cross-State)'
        END AS route_type,
        TIMESTAMPDIFF(HOUR, o.order_purchase_timestamp, o.order_approved_at) AS approval_hours,
        DATEDIFF(o.order_delivered_carrier_date, o.order_approved_at) AS seller_dispatch_days,
        DATEDIFF(o.order_delivered_carrier_date, oi.shipping_limit_date) AS seller_sla_variance_days,
        DATEDIFF(o.order_delivered_customer_date, o.order_delivered_carrier_date) AS carrier_transit_days,
        DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS edd_delay_days
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN sellers s ON oi.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_delivered_carrier_date IS NOT NULL
)
SELECT 
    route_type,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(AVG(seller_dispatch_days), 2) AS avg_seller_dispatch_days,
    ROUND(AVG(carrier_transit_days), 2) AS avg_carrier_transit_days,
    SUM(CASE WHEN edd_delay_days > 0 THEN 1 ELSE 0 END) AS late_orders,
    ROUND(
        100.0 * SUM(CASE WHEN edd_delay_days > 0 THEN 1 ELSE 0 END) / COUNT(*), 2
    ) AS sla_breach_rate_pct,
    ROUND(
        100.0 * SUM(CASE WHEN edd_delay_days > 0 THEN 1 ELSE 0 END) / 
        SUM(SUM(CASE WHEN edd_delay_days > 0 THEN 1 ELSE 0 END)) OVER (), 2
    ) AS share_of_total_late_orders_pct
FROM fulfillment_stages
GROUP BY route_type;

-- ----------------------------------------------------------------------------
-- QUERY 2: Pareto Audit of Seller Dispatch Breaches (Window Functions)
-- Proves how a small subset (~12%) of sellers drives 50%+ of handover delays
-- ----------------------------------------------------------------------------
WITH seller_breach_counts AS (
    SELECT 
        oi.seller_id,
        s.seller_state,
        COUNT(DISTINCT o.order_id) AS total_orders_handled,
        SUM(CASE 
            WHEN o.order_delivered_carrier_date > oi.shipping_limit_date THEN 1 
            ELSE 0 
        END) AS dispatch_breach_count
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN sellers s ON oi.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id, s.seller_state
),
pareto_calc AS (
    SELECT 
        seller_id,
        seller_state,
        total_orders_handled,
        dispatch_breach_count,
        ROW_NUMBER() OVER (ORDER BY dispatch_breach_count DESC) AS seller_rank,
        COUNT(*) OVER () AS total_sellers,
        SUM(dispatch_breach_count) OVER (
            ORDER BY dispatch_breach_count DESC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_breaches,
        SUM(dispatch_breach_count) OVER () AS grand_total_breaches
    FROM seller_breach_counts
)
SELECT 
    seller_id,
    seller_state,
    total_orders_handled,
    dispatch_breach_count,
    ROUND(100.0 * seller_rank / total_sellers, 2) AS cumulative_seller_pct,
    ROUND(100.0 * running_breaches / grand_total_breaches, 2) AS cumulative_breach_share_pct
FROM pareto_calc
WHERE running_breaches <= 0.55 * grand_total_breaches
ORDER BY seller_rank;

-- ----------------------------------------------------------------------------
-- QUERY 3: SLA Breach vs. Customer Review Score Cliff
-- Demonstrates the drop from 4.29★ (On-Time) to 2.25★ (1-3 Days Late)
-- ----------------------------------------------------------------------------
WITH order_delay_buckets AS (
    SELECT 
        o.order_id,
        r.review_score,
        DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS delay_days,
        CASE 
            WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) <= 0 
                THEN '1. Early / On-Time (<= 0 Days)'
            WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) BETWEEN 1 AND 3 
                THEN '2. Slightly Late (1-3 Days)'
            WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) BETWEEN 4 AND 7 
                THEN '3. Moderately Late (4-7 Days)'
            ELSE '4. Severely Late (> 7 Days)'
        END AS delivery_bucket
    FROM orders o
    JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT 
    delivery_bucket,
    COUNT(order_id) AS total_reviewed_orders,
    ROUND(100.0 * COUNT(order_id) / SUM(COUNT(order_id)) OVER (), 2) AS order_share_pct,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) AS one_star_reviews,
    ROUND(
        100.0 * SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) / COUNT(order_id), 2
    ) AS one_star_rate_pct
FROM order_delay_buckets
GROUP BY delivery_bucket
ORDER BY delivery_bucket;
