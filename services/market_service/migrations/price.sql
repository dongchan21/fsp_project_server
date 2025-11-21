CREATE TABLE price (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(10) NOT NULL,
    date DATE NOT NULL,
    close NUMERIC(10, 2) NOT NULL,
    
    CONSTRAINT unique_symbol_date UNIQUE (symbol, date)
);

CREATE INDEX idx_price_symbol_date ON price (symbol, date);
CREATE INDEX idx_price_date ON price (date);
CREATE INDEX idx_price_symbol ON price (symbol);
