# SQL Best Practices

This document outlines the best practices for writing efficient, maintainable, and secure SQL queries and database schemas. These guidelines apply to most SQL databases, with notes for specific database systems where applicable.

## SQL writing guidance
### Add N to unicode string
#### Example
N'Tên'
### Always alias column and table names
#### Example 1: 
##### Bad
SELECT rrl.id, rrl.report_id FROM rp_report_list AS rrl;
##### Good
SELECT rrl.id AS id, rrl.report_id AS report_id FROM rp_report_list AS rrl;
### Simplify "CASE WHEN" when possible. 
#### Example 1: 
##### Bad
CASE WHEN drlf.report_id IS NOT NULL THEN TRUE ELSE FALSE END
##### Good
drlf.report_id IS NOT NULL
#### Example 2: 
##### Bad
CASE WHEN (a.amount - b.amount) >= 0 then (a.amount - b.amount) ELSE 0 END;
##### Good
GREATEST(0, a.amount - b.amount);

### Prefer CTEs Over Nested Subqueries
#### Example 1: 
##### Bad
SELECT u.user_name as user_name, uo.order_count as order_count 
FROM user u 
INNER JOIN (
    SELECT o.user_id as user_id, COUNT(*) as order_count 
    FROM orders o
    GROUP BY user_id
) AS user_orders uo ON u.user_id = uo.user_id
WHERE uo.order_count > 5;

##### Good
WITH user_orders AS (
    SELECT o.user_id as user_id, COUNT(*) as order_count 
    FROM orders o
    GROUP BY o.user_id
)
SELECT u.user_name as user_name, uo.order_count as order_count 
FROM user u
INNER JOIN user_orders uo ON u.user_id = uo.user_id
WHERE uo.order_count > 5;


