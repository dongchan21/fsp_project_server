# FSP Microservices Architecture (Initial Scaffold)

## Services

- **market_service** (8081): Provides forex and price endpoints (placeholder). Will ingest and cache data in Redis, persist history in Postgres.
- **backtest_service** (8082): Accepts backtest jobs, will enqueue to Redis and store results/metadata in Postgres.
- **ai_service** (8083): Performs analysis and AI feedback endpoints. Future: model integration & caching.

## Shared Package

`packages/fsp_shared`: Common models (e.g., BacktestRequest, BacktestJobStatus). Extend with error types, DTOs, and utilities.

## Running Locally

```bash
# At repo root
docker compose build
docker compose up -d

# Check health
curl http://localhost:8081/healthz
curl http://localhost:8082/healthz
curl http://localhost:8083/healthz
```

## Environment Variables (Per Service)

- `PORT`: Service listen port
- `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- `REDIS_HOST`

## Next Steps

1. Implement Redis job queue for backtests (list or stream).
2. Persist market data ingestion schedule (cron + ingestion table).
3. Add structured logging + metrics endpoint (`/metrics`).
4. Introduce gateway / API aggregation if Flutter needs simplified endpoints.
5. Add authentication (API key/JWT) layer.
6. Write OpenAPI specs for each service.

## Suggested Directory Additions

- `infra/` for Terraform/K8s manifests (future)
- `gateway/` for BFF / API consolidation (optional)

## Testing

Use `dart test` inside each service directory. Add contract tests in a new `packages/fsp_client` later.

## Notes

This scaffold is minimal; endpoints are placeholders and must be wired to real logic. Extend models in `fsp_shared` as contracts stabilize.
