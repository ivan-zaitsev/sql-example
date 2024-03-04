INSERT INTO users(username, email)
SELECT
    'user' || generate_series(1, 100000),
    'user' || generate_series(1, 100000) || '@example.com';

INSERT INTO products(name, price)
SELECT
    'Product' || generate_series(1, 1000),
    floor(random() * 100)::int;

INSERT INTO orders(user_id, created_at)
SELECT
    id,
    CURRENT_TIMESTAMP - interval '1' day * floor(random() * 10)::int
FROM (
    SELECT 
        id,
        floor(random() * 10)::int as orders_quantity
    FROM users
) AS users_orders
CROSS JOIN generate_series(1, users_orders.orders_quantity) as orders;

INSERT INTO orders_items(order_id, product_id, quantity)
SELECT
    o.id,
    p.id,
    floor(random() * 5)::int + 1
FROM orders o
JOIN products p ON true
WHERE random() < 0.5;
