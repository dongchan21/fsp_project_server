-- Adjust existing prices table to new schema if migrating from old structure
-- Old: prices(symbol, price, as_of, created_at)
-- New: price(id, symbol, date, close)

-- If old table exists rename & transform.
DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'prices') THEN
    -- Create new table if not exists
    CREATE TABLE IF NOT EXISTS price (
      id BIGSERIAL PRIMARY KEY,
      symbol TEXT NOT NULL,
      date DATE NOT NULL,
      close DOUBLE PRECISION NOT NULL
    );
    -- Migrate data (take as_of::date and price)
    INSERT INTO price(symbol, date, close)
    SELECT symbol, DATE(as_of), price FROM prices
    ON CONFLICT DO NOTHING;
    -- Optionally drop old table
    DROP TABLE prices;
  ELSE
    -- If new table not there create
    IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'price') THEN
      CREATE TABLE price (
        id BIGSERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        date DATE NOT NULL,
        close DOUBLE PRECISION NOT NULL
      );
    END IF;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_price_symbol_date ON price(symbol, date DESC);
