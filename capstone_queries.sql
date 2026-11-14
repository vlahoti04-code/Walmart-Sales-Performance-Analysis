-- ============================================================
-- Data Analytics at Walmart - Phase 1: Advanced SQL Analysis
-- Tool: MySQL 8+
-- Queries typed from the screenshots in the capstone PDF.
-- Tables: customers, geolocation, mytable, order_items, orders,
--         payments, products, sellers
-- ============================================================

-- ------------------------------------------------------------
-- 1. Total sales revenue and quantity sold by product category
--    and customer_state
-- ------------------------------------------------------------
SELECT
    UPPER(p.product_category) AS product_category,
    c.customer_state,
    COUNT(ot.order_item_id) AS quantity_sold,
    ROUND(SUM(ot.price + ot.freight_value), 2) AS total_sales_revenue
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items ot ON ot.order_id = o.order_id
JOIN products p ON ot.product_id = p.product_id
GROUP BY UPPER(p.product_category), c.customer_state
ORDER BY total_sales_revenue DESC;

-- ------------------------------------------------------------
-- 2. Top 5 products (categories) by total sales revenue
-- ------------------------------------------------------------
WITH allProducts AS (
    SELECT
        UPPER(p.product_category) AS product_category,
        ROUND(SUM(ot.price + ot.freight_value), 2) AS total_sales_revenue
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items ot ON ot.order_id = o.order_id
    JOIN products p ON ot.product_id = p.product_id
    GROUP BY UPPER(p.product_category)
)
SELECT
    product_category,
    total_sales_revenue
FROM allProducts
ORDER BY total_sales_revenue DESC
LIMIT 5;

-- ------------------------------------------------------------
-- 3. Most valuable customers (highest number of orders + spend)
-- ------------------------------------------------------------
WITH allCustomers AS (
    SELECT
        c.customer_id,
        COUNT(ot.order_item_id) AS quantity_sold,
        ROUND(SUM(ot.price + ot.freight_value), 2) AS amount_spend
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items ot ON ot.order_id = o.order_id
    GROUP BY c.customer_id
),
ranked AS (
    SELECT
        customer_id,
        quantity_sold,
        amount_spend,
        DENSE_RANK() OVER (ORDER BY quantity_sold DESC) AS rank_qty,
        DENSE_RANK() OVER (ORDER BY amount_spend DESC) AS rank_amt
    FROM allCustomers
),
combined AS (
    SELECT *,
        (rank_qty + rank_amt) AS total_rank
    FROM ranked
)
SELECT
    customer_id,
    quantity_sold,
    amount_spend,
    total_rank
FROM combined
ORDER BY total_rank ASC
LIMIT 10;

-- ------------------------------------------------------------
-- 4. Customer states with the highest average order value (AOV)
-- ------------------------------------------------------------
WITH order_totals AS (
    SELECT
        o.order_id,
        c.customer_state,
        ROUND(SUM(ot.price + ot.freight_value), 2) AS total_amount_spend
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items ot ON ot.order_id = o.order_id
    GROUP BY o.order_id, c.customer_state
),
average_by_state AS (
    SELECT
        customer_state,
        ROUND(AVG(total_amount_spend), 2) AS average_order_value
    FROM order_totals
    GROUP BY customer_state
),
ranked_states AS (
    SELECT
        customer_state,
        average_order_value,
        DENSE_RANK() OVER (ORDER BY average_order_value DESC) AS rank_aov
    FROM average_by_state
)
SELECT
    customer_state,
    average_order_value
FROM ranked_states
WHERE rank_aov <= 10
ORDER BY average_order_value DESC;

-- ------------------------------------------------------------
-- 5. Average delivery time (days) by seller state
-- ------------------------------------------------------------
SELECT
    s.seller_state,
    ROUND(AVG(TIMESTAMPDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date)), 1) AS avg_delivery_days
FROM orders o
JOIN order_items ot ON ot.order_id = o.order_id
JOIN sellers s ON s.seller_id = ot.seller_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY s.seller_state
ORDER BY avg_delivery_days DESC;

-- ------------------------------------------------------------
-- 6. Top 5 sellers based on total revenue earned
-- ------------------------------------------------------------
WITH sales_revenue_ranking AS (
    SELECT
        s.seller_id,
        ROUND(SUM(ot.price + ot.freight_value), 2) AS total_revenue_earned
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items ot ON ot.order_id = o.order_id
    JOIN sellers s ON s.seller_id = ot.seller_id
    GROUP BY s.seller_id
),
ranked_sellers AS (
    SELECT
        seller_id,
        total_revenue_earned,
        DENSE_RANK() OVER (ORDER BY total_revenue_earned DESC) AS sales_revenue_rank
    FROM sales_revenue_ranking
)
SELECT
    seller_id,
    total_revenue_earned,
    sales_revenue_rank
FROM ranked_sellers
WHERE sales_revenue_rank <= 5
ORDER BY sales_revenue_rank, total_revenue_earned DESC;

-- ------------------------------------------------------------
-- 7. Monthly revenue trend over the last 12 months
-- ------------------------------------------------------------
WITH monthly_sales AS (
    SELECT
        YEAR(o.order_purchase_timestamp) AS sales_year,
        MONTH(o.order_purchase_timestamp) AS sales_month_number,
        DATE_FORMAT(MIN(o.order_purchase_timestamp), '%M') AS sales_month_name,
        ROUND(SUM(ot.price + ot.freight_value), 2) AS total_sales_revenue
    FROM orders o
    JOIN order_items ot ON ot.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp)
),
with_lag AS (
    SELECT
        sales_year,
        sales_month_number,
        sales_month_name,
        total_sales_revenue,
        LAG(total_sales_revenue) OVER (ORDER BY sales_year, sales_month_number) AS previous_month_sales
    FROM monthly_sales
)
SELECT
    sales_year,
    sales_month_name,
    sales_month_number,
    total_sales_revenue,
    previous_month_sales,
    ROUND(total_sales_revenue - previous_month_sales, 2) AS difference_total_sales_revenue,
    ROUND(
        ((total_sales_revenue - previous_month_sales) / NULLIF(previous_month_sales, 0)) * 100,
        2
    ) AS pct_change
FROM with_lag
ORDER BY sales_year DESC, sales_month_number DESC
LIMIT 12;

-- ------------------------------------------------------------
-- 8. New unique customers acquired each month
-- ------------------------------------------------------------
WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase_date
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    YEAR(first_purchase_date) AS year,
    MONTH(first_purchase_date) AS month_number,
    DATE_FORMAT(first_purchase_date, '%M') AS month_name,
    COUNT(*) AS new_customers
FROM first_purchase
GROUP BY YEAR(first_purchase_date), MONTH(first_purchase_date), DATE_FORMAT(first_purchase_date, '%M')
ORDER BY year DESC, month_number;

-- ------------------------------------------------------------
-- 9. Rank customers by lifetime spend within each customer state
-- ------------------------------------------------------------
WITH allCustomers AS (
    SELECT
        c.customer_id,
        c.customer_state,
        ROUND(SUM(ot.price + ot.freight_value), 2) AS amount_spend
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items ot ON ot.order_id = o.order_id
    JOIN products p ON ot.product_id = p.product_id
    GROUP BY c.customer_id, c.customer_state
)
SELECT
    customer_id,
    customer_state,
    amount_spend,
    DENSE_RANK() OVER (PARTITION BY customer_state ORDER BY amount_spend DESC) AS rank_amount_spend
FROM allCustomers;

-- ------------------------------------------------------------
-- 10. Rolling 3-month average revenue trend
-- ------------------------------------------------------------
WITH total_sales AS (
    SELECT
        YEAR(o.order_purchase_timestamp) AS purchase_year,
        MONTH(o.order_purchase_timestamp) AS purchase_month,
        ROUND(SUM(ot.price + ot.freight_value), 2) AS total_sales_revenue
    FROM orders o
    JOIN order_items ot ON ot.order_id = o.order_id
    GROUP BY YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp)
)
SELECT
    purchase_year,
    purchase_month,
    total_sales_revenue,
    ROUND(
        AVG(total_sales_revenue) OVER (
            ORDER BY purchase_year, purchase_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS rolling_3_month_avg_revenue
FROM total_sales
ORDER BY purchase_year, purchase_month;
