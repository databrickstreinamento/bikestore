SELECT
  oi.order_id,
  oi.item_id,
  oi.quantity,
  oi.list_price,
  oi.discount,
  o.order_date,
  o.customer_id,
  p.product_id,
  p.category_id,
  p.brand_id,
  (oi.list_price * oi.quantity) AS gross_amount,
  (oi.list_price * oi.quantity * (1 - oi.discount)) AS net_amount
FROM silver.fact_orders_items oi
JOIN silver.fact_orders o USING (order_id)
JOIN silver.dim_product p USING (product_id)
