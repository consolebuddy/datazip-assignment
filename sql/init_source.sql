CREATE TABLE IF NOT EXISTS orders (
  order_id      SERIAL PRIMARY KEY,
  customer_id   INT NOT NULL,
  order_date    TIMESTAMP NOT NULL DEFAULT NOW(),
  status        VARCHAR(20) NOT NULL,
  amount        NUMERIC(10,2) NOT NULL
);

INSERT INTO orders (customer_id, order_date, status, amount) VALUES
  (101, NOW() - INTERVAL '10 days', 'PLACED',  1299.99),
  (102, NOW() - INTERVAL '9 days',  'PLACED',   199.50),
  (101, NOW() - INTERVAL '8 days',  'SHIPPED',  349.00),
  (103, NOW() - INTERVAL '7 days',  'CANCELLED',  0.00),
  (104, NOW() - INTERVAL '6 days',  'PLACED',   999.00),
  (105, NOW() - INTERVAL '5 days',  'DELIVERED', 89.90),
  (106, NOW() - INTERVAL '4 days',  'DELIVERED', 59.99),
  (101, NOW() - INTERVAL '3 days',  'PLACED',   249.49),
  (107, NOW() - INTERVAL '2 days',  'PLACED',   149.00),
  (108, NOW() - INTERVAL '1 days',  'SHIPPED',  579.00),
  (109, NOW(),                      'PLACED',    49.99),
  (110, NOW(),                      'PLACED',   749.00);
