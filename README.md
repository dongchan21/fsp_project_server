# 🖥️ FSP Backend Server

The backend infrastructure for the Financial Strategy Portfolio (FSP) platform. It is built as a set of microservices to handle market data, backtesting logic, and AI analysis independently.

---

## 🛠 Tech Stack

- **Language**: Dart (Main Services), Python (Data Fetching & AI)
- **Framework**:
  - **Dart**: `shelf` (Web Server), `http`
  - **Python**: `FastAPI` (Price Fetcher)
- **Infrastructure**: Docker, Docker Compose
- **Database/Cache**: Redis (Caching), PostgreSQL (Persistence - planned)
- **Gateway**: Custom Dart-based API Gateway

---

## 🧩 Microservices Overview

| Service              | Port   | Description                                                                  |
| -------------------- | ------ | ---------------------------------------------------------------------------- |
| **Gateway**          | `8080` | Unified entry point for the client. Routes requests to appropriate services. |
| **Market Service**   | `8081` | Manages stock price data. Fetches from external APIs and caches results.     |
| **Backtest Service** | `8082` | Core engine for calculating portfolio performance (CAGR, MDD, Sharpe Ratio). |
| **AI Service**       | `8083` | Generates investment insights using LLMs based on backtest results.          |
| **Price Fetcher**    | `8090` | Python-based service for fetching raw financial data (yfinance, etc.).       |

---

## 🚀 Getting Started

### Prerequisites

- Docker & Docker Compose installed.
- Dart SDK (optional, for local dev).

### Running with Docker (Recommended)

```bash
# Build and start all services
docker compose up --build -d

# Check logs
docker compose logs -f
```

### API Endpoints (Gateway)

- `POST /api/backtest/run`: Run a portfolio backtest.
- `POST /api/ai/analyze`: Request AI analysis for a result.
- `GET /health`: Check system health.

---

## 📂 Project Structure

```
fsp_server/
├── bin/                 # Entry points for Dart services
├── lib/                 # Shared business logic and models
├── services/            # Microservice implementations
│   ├── ai_service/      # AI Logic
│   ├── backtest_service/# Backtest Engine
│   ├── market_service/  # Market Data Manager
│   └── price_fetcher/   # Python Data Fetcher
├── docker-compose.yml   # Container orchestration
└── Dockerfile           # Multi-stage build definition
```
