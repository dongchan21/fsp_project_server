# Price Fetcher Service (FastAPI + Yahoo Finance)

Fetches latest and historical stock prices from Yahoo Finance (via `yfinance`), upserts them into the shared `price` Postgres table, and exposes simple HTTP endpoints for integration.

## Endpoints

- `GET /healthz` : Liveness
- `GET /readyz` : Readiness (tries DB connection)
- `GET /prices/latest/{symbol}` : Latest price (close) for symbol
- `GET /prices/history/{symbol}?start=YYYY-MM-DD&end=YYYY-MM-DD&interval=1mo` : Historical prices
  - `interval` supports `1d|1wk|1mo`

## Environment Variables

| Name              | Default   | Description   |
| ----------------- | --------- | ------------- |
| POSTGRES_HOST     | localhost | Postgres host |
| POSTGRES_PORT     | 5432      | Postgres port |
| POSTGRES_DB       | fsp       | Database name |
| POSTGRES_USER     | fsp       | DB user       |
| POSTGRES_PASSWORD | fsp       | DB password   |

## Docker

```bash
# Build
docker build -t price_fetcher:local ./services/price_fetcher
# Run (adjust env vars as needed)
docker run --rm -p 8090:8090 \
  -e POSTGRES_HOST=host.docker.internal \
  -e POSTGRES_DB=fsp -e POSTGRES_USER=fsp -e POSTGRES_PASSWORD=fsp \
  price_fetcher:local
```

## Local Dev

```bash
cd services/price_fetcher
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8090
```

## Sample Calls

```bash
# Latest
curl http://localhost:8090/prices/latest/AAPL
# History (monthly)
curl "http://localhost:8090/prices/history/AAPL?start=2020-01-01&end=2024-12-01&interval=1mo"
```

## Integration (Dart market_service)

When price cache and DB miss occur, the Dart service can call `PRICE_FETCHER_URL` (e.g. `http://localhost:8090`) for `/prices/latest/{symbol}`; the fetcher will upsert into Postgres so subsequent DB hits succeed.

## Notes

- Yahoo Finance data may have slight delays or adjustments; consider validation before trading logic.
- Rate limiting: heavy bulk requests should be batched or cached aggressively.
- For production robustness, add retry & circuit breaker around external API calls.
