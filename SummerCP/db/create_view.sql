-- всё время
create view top_instruments_all as
select 
    i.id,
    i.i_name,
    count(o.id) as rental_count,
    coalesce(sum(o.discounted_price), 0) as total_revenue
from instrument i
left join orders o on o.id_instrument = i.id and o.status in ('оплачено', 'возвращено')
group by i.id, i.i_name
order by rental_count desc;

-- последние 30 дней (месяц)
create view top_instruments_month as
select 
    i.id,
    i.i_name,
    count(o.id) as rental_count,
    coalesce(sum(o.discounted_price), 0) as total_revenue
from instrument i
left join orders o on o.id_instrument = i.id 
    and o.status in ('оплачено', 'возвращено')
    and o.start_date >= current_date - interval '30 days'
group by i.id, i.i_name
order by rental_count desc;

-- последние 90 дней (квартал)
create view top_instruments_quarter as
select 
    i.id,
    i.i_name,
    count(o.id) as rental_count,
    coalesce(sum(o.discounted_price), 0) as total_revenue
from instrument i
left join orders o on o.id_instrument = i.id 
    and o.status in ('оплачено', 'возвращено')
    and o.start_date >= current_date - interval '90 days'
group by i.id, i.i_name
order by rental_count desc;

-- последние 180 дней (полгода)
create view top_instruments_half_year as
select 
    i.id,
    i.i_name,
    count(o.id) as rental_count,
    coalesce(sum(o.discounted_price), 0) as total_revenue
from instrument i
left join orders o on o.id_instrument = i.id 
    and o.status in ('оплачено', 'возвращено')
    and o.start_date >= current_date - interval '180 days'
group by i.id, i.i_name
order by rental_count desc;

-- последние 365 дней (год)
create view top_instruments_year as
select 
    i.id,
    i.i_name,
    count(o.id) as rental_count,
    coalesce(sum(o.discounted_price), 0) as total_revenue
from instrument i
left join orders o on o.id_instrument = i.id 
    and o.status in ('оплачено', 'возвращено')
    and o.start_date >= current_date - interval '365 days'
group by i.id, i.i_name
order by rental_count desc;

-- всё время
create view top_customers_all as
select 
    c.id,
    concat(c.l_name, ' ', c.f_name) as full_name,
    c.phone,
    count(o.id) as rental_count,
    coalesce(sum(o.discounted_price), 0) as total_spent
from customer c
left join orders o on o.id_customer = c.id and o.status in ('оплачено', 'возвращено')
group by c.id, c.l_name, c.f_name, c.phone
order by total_spent desc;

-- последние 30 дней (месяц)
create view top_customers_month as
select 
    c.id,
    concat(c.l_name, ' ', c.f_name) as full_name,
    c.phone,
    count(o.id) as rental_count,
    coalesce(sum(o.discounted_price), 0) as total_spent
from customer c
left join orders o on o.id_customer = c.id 
    and o.status in ('оплачено', 'возвращено')
    and o.start_date >= current_date - interval '30 days'
group by c.id, c.l_name, c.f_name, c.phone
order by total_spent desc;

-- последние 90 дней
create view top_customers_quarter as
select 
    c.id,
    concat(c.l_name, ' ', c.f_name) as full_name,
    c.phone,
    count(o.id) as rental_count,
    coalesce(sum(o.discounted_price), 0) as total_spent
from customer c
left join orders o on o.id_customer = c.id 
    and o.status in ('оплачено', 'возвращено')
    and o.start_date >= current_date - interval '90 days'
group by c.id, c.l_name, c.f_name, c.phone
order by total_spent desc;

-- последние 180 дней
create view top_customers_half_year as
select 
    c.id,
    concat(c.l_name, ' ', c.f_name) as full_name,
    c.phone,
    count(o.id) as rental_count,
    coalesce(sum(o.discounted_price), 0) as total_spent
from customer c
left join orders o on o.id_customer = c.id 
    and o.status in ('оплачено', 'возвращено')
    and o.start_date >= current_date - interval '180 days'
group by c.id, c.l_name, c.f_name, c.phone
order by total_spent desc;

-- последние 365 дней
create view top_customers_year as
select 
    c.id,
    concat(c.l_name, ' ', c.f_name) as full_name,
    c.phone,
    count(o.id) as rental_count,
    coalesce(sum(o.discounted_price), 0) as total_spent
from customer c
left join orders o on o.id_customer = c.id 
    and o.status in ('оплачено', 'возвращено')
    and o.start_date >= current_date - interval '365 days'
group by c.id, c.l_name, c.f_name, c.phone
order by total_spent desc;



drop view if exists revenue_all cascade;
drop view if exists revenue_by_month cascade;
drop view if exists revenue_by_season cascade;
drop view if exists revenue_half_year cascade;
drop view if exists revenue_year cascade;

-- общая прибыль
create view revenue_all as
select 
    coalesce(sum(discounted_price), 0) as total_revenue,
    count(id) as total_orders,
    coalesce(avg(discounted_price), 0) as avg_order_value
from orders
where status in ('оплачено', 'возвращено');

-- прибыль по месяцам (последние 12 месяцев)
create view revenue_by_month as
select 
    to_char(date_trunc('month', start_date), 'yyyy-mm') as month,
    coalesce(sum(discounted_price), 0) as revenue,
    count(id) as orders_count
from orders
where status in ('оплачено', 'возвращено')
    and start_date >= date_trunc('month', current_date) - interval '12 months'
group by date_trunc('month', start_date)
order by month desc;

-- прибыль по месяцам за полгода с накоплением
create view revenue_half_year as
select 
    to_char(date_trunc('month', start_date), 'yyyy-mm') as month,
    coalesce(sum(discounted_price), 0) as revenue,
    count(id) as orders_count,
    sum(coalesce(sum(discounted_price), 0)) over (order by date_trunc('month', start_date)) as cumulative_revenue
from orders
where status in ('оплачено', 'возвращено')
    and start_date >= date_trunc('month', current_date) - interval '6 months'
group by date_trunc('month', start_date)
order by month;

-- прибыль по месяцам за год с накоплением
create view revenue_year as
select 
    to_char(date_trunc('month', start_date), 'yyyy-mm') as month,
    coalesce(sum(discounted_price), 0) as revenue,
    count(id) as orders_count,
    sum(coalesce(sum(discounted_price), 0)) over (order by date_trunc('month', start_date)) as cumulative_revenue
from orders
where status in ('оплачено', 'возвращено')
    and start_date >= date_trunc('month', current_date) - interval '12 months'
group by date_trunc('month', start_date)
order by month;


truncate table orders, customer, passport cascade;

alter sequence orders_id_seq restart with 1;
alter sequence customer_id_seq restart with 1;
alter sequence passport_id_seq restart with 1;