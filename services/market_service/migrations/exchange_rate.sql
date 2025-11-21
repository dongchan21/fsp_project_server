CREATE TABLE exchange_rate (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    rate NUMERIC(12, 4) NOT NULL,

    CONSTRAINT unique_exchange_date UNIQUE (date)
);

CREATE INDEX idx_exchange_rate_date ON exchange_rate (date);