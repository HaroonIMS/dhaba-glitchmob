-- Schema and sample data for Dhaba Orders (no secrets in here).
CREATE TABLE IF NOT EXISTS menu (
  id    SERIAL PRIMARY KEY,
  name  TEXT NOT NULL,
  price NUMERIC(8,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS orders (
  id         SERIAL PRIMARY KEY,
  items      JSONB NOT NULL,
  status     TEXT NOT NULL DEFAULT 'new',  -- new | cooking | ready
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO menu (name, price)
SELECT * FROM (VALUES
  ('Chicken Karahi', 12.50),
  ('Biryani', 9.00),
  ('Daal Tadka', 6.50),
  ('Garlic Naan', 1.50),
  ('Mango Lassi', 3.00)
) AS v(name, price)
WHERE NOT EXISTS (SELECT 1 FROM menu);
