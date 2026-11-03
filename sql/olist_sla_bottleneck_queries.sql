-- Olist E-Commerce Logistics SLA & Bottleneck Analysis (PostgreSQL)

-- 1. Seller Dispatch Bottleneck & Pareto Delay Concentration
WITH seller_delay_metrics AS (
    SELECT 
        oi.seller_id,
        s.seller_state,
        COUNT(DISTINCT o.order_id) AS total_orders_fulfilled,
        SUM(CASE WHEN o.order_delivered_carrier_date > oi.shipping_limit_date THEN 1 ELSE 0 END) AS late_handover_orders,
        ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_carrier_date - oi.shipping_limit_date)) / 86400.0), 2) AS avg_handover_delay_days
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
        SUM(late_handover_orders) OVER (ORDER BY late_handover_orders DESC) * 100.0 / SUM(late_handover_orders) OVER () AS cumulative_delay_share_pct,
        DENSE_RANK() OVER (ORDER BY late_handover_orders DESC) AS seller_delay_rank
    FROM seller_delay_metrics
)
SELECT * FROM pareto_ranking
WHERE cumulative_delay_share_pct <= 55.0
ORDER BY seller_delay_rank ASC;

-- 2. Delivery SLA Breach vs. Customer Review Score Degradation
WITH delivery_sla_cohorts AS (
    SELECT 
        o.order_id,
        r.review_score,
        ROUND(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0, 1) AS sla_variance_days,
        CASE 
            WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 'On-Time (Within SLA)'
            WHEN EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0 BETWEEN 0.1 AND 3.0 THEN 'Minor Delay (1-3 Days)'
            WHEN EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0 BETWEEN 3.1 AND 7.0 THEN 'Moderate Delay (4-7 Days)'
            ELSE 'Severe SLA Breach (7+ Days)'
        END AS sla_cohort
    FROM olist_orders_dataset o
    JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
)
SELECT 
    sla_cohort,
    COUNT(order_id) AS total_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(order_id), 2) AS one_star_complaint_rate_pct
FROM delivery_sla_cohorts
GROUP BY sla_cohort
ORDER BY avg_review_score DESC;

