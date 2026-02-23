--SQL Queries based on stakeholder questions:

-- 1)  What is the average quarterly order count and total sales for Macbooks sold in North America? 

with macbook_NA_cte as (
   select extract(year from purchase_ts) as year, 
     extract(quarter from purchase_ts) as quarter,
     count( distinct orders.id ) as order_count,
     sum(orders.usd_price) as total_sales
   from core.orders
   left join core.customers
     on orders.customer_id = customers.id
   left join core.geo_lookup
  on customers.country_code = geo_lookup.country_code
   where lower(orders.product_name) like '%macbook%'
     and geo_lookup.region = 'NA'
   group by 1,2
   order by 1 desc, 2 desc
)

select year, 
  quarter,
  round(avg(order_count),2) as avg_qrtly_orders,
  round(avg(total_sales),2) as avg_qrtly_sales
from macbook_NA_cte
group by 1,2
order by 1 desc, 2 desc;

-- 2) For products purchased in 2022 on the website or products purchased on mobile in any year, which region has the average highest time to deliver?

select geo_lookup.region,
  round(avg(date_diff(order_status.delivery_ts, order_status.purchase_ts, day)),2) as delivery_time
from core.order_status
left join core.orders
  on order_status.order_id = orders.id
left join core.customers
  on orders.customer_id = customers.id
left join core.geo_lookup 
  on customers.country_code = geo_lookup.country_code
where (orders.purchase_platform = 'website' and extract(year from orders.purchase_ts) = 2022)
   or orders.purchase_platform = 'mobile'
group by 1
order by 2 desc;

-- 3) What was the refund rate and refund count for each product overall?  

select case when orders.product_name = '27in"" 4k gaming monitor' then '27in 4K gaming monitor' else orders.product_name end as product_cleaned,
  sum(case when refund_ts is not null then 1 else 0 end) as refund_count,
  round(avg(case when refund_ts is not null then 1 else 0 end),2) as refund_rate
from core.orders
join core.order_status
  on orders.id = order_status.order_id
group by 1
order by 3 desc;

-- 4) Within each region, what is the most popular product?

with orders_by_product_and_region_cte as (
   select geo_lookup.region as region,
  case when product_name = '27in"" 4k gaming monitor' then '27in 4K gaming monitor' else product_name end as    product_clean,
  count( distinct orders.id) as total_orders
from core.orders
left join core.customers
  on orders.customer_id = customers.id
left join core.geo_lookup
  on customers.country_code = geo_lookup.country_code
group by 1,2
),

ranked_order_count_cte as (
   select *,
   rank() over (partition by region order by total_orders desc) as order_count_rank
   from orders_by_product_and_region_cte
)

select *
from ranked_order_count_cte
where order_count_rank = 1
order by total_orders desc;
 
-- 5) How does the time to make a purchase differ between loyalty customers vs. non-loyalty customers?

select customers.loyalty_program,
   round(avg(date_diff(orders.purchase_ts,customers.created_on,day)),1) as days_to_purchase,
   round(avg(date_diff(orders.purchase_ts,customers.created_on,month)),1) as months_to_purchase
from core.customers
left join core.orders
  on customers.id = orders.customer_id
group by 1;
