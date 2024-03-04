# PostgreSQL setup

1. Setup Postgres server
```
docker-compose up -d
```

2. Connect to Postgres server
```
psql -h 127.0.0.1 -p 5432 -U postgres -d postgres
```

# Practice

## Pagination
- OFFSET
- KEYSET (Cursor or Seek)

OFFSET:
```
EXPLAIN ANALYZE
SELECT * FROM users
ORDER BY id ASC
OFFSET 99990 FETCH NEXT 10 ROWS ONLY;
```

KEYSET:
```
EXPLAIN ANALYZE
SELECT * FROM users
WHERE id > 99990
ORDER BY id ASC
LIMIT 10;
```

## ID types
- SEQUENTIAL (Incremental)
- UUID (Random or Sorted)

## Transactions
More: https://www.postgresql.org/docs/current/transaction-iso.html

A - Atomicity
C - Consistency
I - Isolation
D - Durability

Isolation levels:
- Read uncommitted
- Read committed
- Repeatable read
- Serializable

Anomalies:
- dirty read
- non-repeatable read
- phantom read
- lost update
- read skew
- write skew

|                  | dirty read | non-repeatable read | phantom read | lost update | read skew | write skew |
|------------------|------------|---------------------|--------------|-------------|-----------|------------|
| Read uncommitted | -          | +                   | +            | +           | +         | +          |
| Read committed   | -          | +                   | +            | +           | +         | +          |
| Repeatable read  | -          | -                   | -            | -           | -         | +          |
| Serializable     | -          | -                   | -            | -           | -         | -          |

Dirty read:
```
BEGIN TRANSACTION;                                    -- Transaction A
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;     -- Transaction A

UPDATE products SET price = 100 WHERE id = 1;         -- Transaction A

BEGIN TRANSACTION;                                    -- Transaction B

SELECT price FROM products WHERE id = 1;              -- Transaction B: Reads data that transaction A did not commit.
... perofrm some calculations                         -- Transaction B

COMMIT TRANSACTION;                                   -- Transaction A
ROLLBACK TRANSACTION;                                 -- Transaction B: Rollbacks changes, transaction A relied on rollbacked value.
```

Non-repeatable read:
```
BEGIN TRANSACTION;                                    -- Transaction A
--SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;    -- Transaction A

SELECT price FROM products WHERE id = 1;              -- Transaction A

BEGIN TRANSACTION;                                    -- Transaction B

UPDATE products SET price = 100 WHERE id = 1;         -- Transaction B

COMMIT TRANSACTION;                                   -- Transaction B

SELECT price FROM products WHERE id = 1;              -- Transaction A: Data was changed by Transaction B, second select has different value.
... perofrm some calculations                         -- Transaction A

COMMIT TRANSACTION;                                   -- Transaction A
```

Phantom read:
```
BEGIN TRANSACTION;                                    -- Transaction A
--SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;    -- Transaction A

SELECT * FROM orders WHERE user_id = 50;              -- Transaction A

BEGIN TRANSACTION;                                    -- Transaction B

INSERT INTO orders (user_id, created_at)              -- Transaction B
VALUES (50, CURRENT_TIMESTAMP);                       -- Transaction B

COMMIT TRANSACTION;                                   -- Transaction B

SELECT * FROM orders WHERE user_id = 50;              -- Transaction A: A new record was added by Transaction B, data set is different.
... perofrm some calculations                         -- Transaction A

COMMIT TRANSACTION;                                   -- Transaction A
```

Lost update:
```
BEGIN TRANSACTION;                                    -- Transaction A
--SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;    -- Transaction A

SELECT * FROM products WHERE id = 1;                  -- Transaction A

UPDATE products SET price = 100 WHERE id = 1;         -- Transaction A

BEGIN TRANSACTION;                                    -- Transaction B

SELECT * FROM products WHERE id = 1;                  -- Transaction B

UPDATE products SET                                   -- Transaction B
  price = 50, name = '...' WHERE id = 1;              -- Transaction B: Overwrites changes of transaction A

COMMIT TRANSACTION;                                   -- Transaction A
COMMIT TRANSACTION;                                   -- Transaction B
```

Read skew:
```
BEGIN TRANSACTION;                                    -- Transaction A
--SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;    -- Transaction A

SELECT * FROM orders WHERE id = 1;                    -- Transaction A

BEGIN TRANSACTION;                                    -- Transaction B

INSERT INTO orders_items(                             -- Transaction B
  order_id, product_id, quantity) VALUES(1, 1, 1);    -- Transaction B

COMMIT TRANSACTION;                                   -- Transaction B

SELECT * FROM orders_items WHERE order_id = 1;        -- Transaction A: A new record was added by Transaction B, data set is different.
... perofrm some calculations                         -- Transaction A

COMMIT TRANSACTION;                                   -- Transaction A
```

Write skew:
```
BEGIN TRANSACTION;                                    -- Transaction A
--SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;       -- Transaction A

SELECT SUM(oi.quantity * p.price)                     -- Transaction A
FROM orders_items oi                                  -- Transaction A
JOIN products p ON oi.product_id = p.id               -- Transaction A
WHERE oi.order_id = 1;                                -- Transaction A

BEGIN TRANSACTION;                                    -- Transaction B
--SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;       -- Transaction A

SELECT SUM(oi.quantity * p.price)                     -- Transaction B
FROM orders_items oi                                  -- Transaction B
JOIN products p ON oi.product_id = p.id               -- Transaction B
WHERE oi.order_id = 1;                                -- Transaction B

INSERT INTO orders_items(                             -- Transaction B
  order_id, product_id, quantity) VALUES(1, 1, 1);    -- Transaction B

COMMIT TRANSACTION;                                   -- Transaction B

INSERT INTO orders_items(                             -- Transaction B
  order_id, product_id, quantity) VALUES(1, 1, 1);    -- Transaction B: Transaction A already inserted order item.

COMMIT TRANSACTION;                                   -- Transaction A
```

## Locks
More: https://www.postgresql.org/docs/current/explicit-locking.html

- Optimistic
- Pessimistic

Optimistic:
- Timestamp
- Integer (Version)

Integer:
```
BEGIN TRANSACTION;                                    -- Transaction A

SELECT * FROM products WHERE id = 1;                  -- Transaction A

UPDATE products SET                                   -- Transaction A
  price = 100, version = version + 1                  -- Transaction A
WHERE id = 1 and version = 1;                         -- Transaction A

BEGIN TRANSACTION;                                    -- Transaction B

SELECT * FROM products WHERE id = 1;                  -- Transaction B

UPDATE products SET                                   -- Transaction B
  price = 50, name = '...', version = version + 1     -- Transaction B
WHERE id = 1 AND version = 1;                         -- Transaction B: Cannot update because version is different

COMMIT TRANSACTION;                                   -- Transaction A
COMMIT TRANSACTION;                                   -- Transaction B
```

Pessimistic:
- Row level
- Table level

Row level:
Read lock (FOR SHARE): allows read, prevents write
Write lock (FOR UPDATE): prevents read and write

Example:
```
BEGIN TRANSACTION;                                    -- Transaction A

SELECT * FROM products WHERE id = 1 FOR SHARE;        -- Transaction A
UPDATE products SET price = 100 WHERE id = 1;         -- Transaction A

BEGIN TRANSACTION;                                    -- Transaction B

SELECT * FROM products WHERE id = 1;                  -- Transaction B

UPDATE products SET                                   -- Transaction B
  price = 50, name = '...' WHERE id = 1;              -- Transaction B: Cannot update because of share lock.

COMMIT TRANSACTION;                                   -- Transaction A
COMMIT TRANSACTION;                                   -- Transaction B
```
