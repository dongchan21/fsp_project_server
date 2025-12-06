# 🏗️ Backend Architecture & Design

## 1. Microservices Architecture

The FSP Backend is designed as a loosely coupled system of microservices, orchestrated via Docker Compose. This allows for independent scaling and maintenance of each component.

```mermaid
graph TD
    Client[Flutter Client] -->|HTTP/JSON| Gateway[API Gateway :8080]

    subgraph "Docker Network"
        Gateway -->|/market| Market[Market Service :8081]
        Gateway -->|/backtest| Backtest[Backtest Service :8082]
        Gateway -->|/ai| AI[AI Service :8083]

        Market -->|gRPC/HTTP| Fetcher[Price Fetcher (Python) :8090]
        AI -->|API| OpenAI[OpenAI API]
    end

    Fetcher -->|External| Yahoo[Yahoo Finance]
```

---

## 2. Service Communication

### Gateway Pattern

- **Role**: The Gateway acts as the single source of truth for the client. It handles CORS, authentication (planned), and request routing.
- **Benefit**: The client doesn't need to know the internal ports or IP addresses of the microservices.

### Polyglot Services (Dart + Python)

- **Dart**: Used for the main business logic (Backtest, Market) due to its strong typing and performance.
- **Python**: Used for `Price Fetcher` to leverage the rich ecosystem of financial libraries (`yfinance`, `pandas`).
- **Inter-service Communication**: Services communicate via HTTP REST APIs within the Docker network.

---

## 3. Data Flow: Backtest Execution

1.  **Request**: Gateway receives a backtest request with symbols and weights.
2.  **Data Check**: Backtest Service asks Market Service for historical data.
3.  **Fetch/Cache**:
    - Market Service checks Redis cache.
    - If miss, calls Python Price Fetcher.
    - Price Fetcher downloads data from Yahoo Finance.
4.  **Compute**: Backtest Service calculates daily returns, CAGR, and MDD.
5.  **Response**: Results are returned to the Gateway -> Client.

---

## 4. AI Analysis Pipeline

To ensure low latency for the user:

1.  **Async Trigger**: When a backtest finishes, the client triggers an AI analysis request immediately (Prefetching).
2.  **Processing**: AI Service constructs a prompt with the performance metrics and sends it to the LLM.
3.  **Result**: The text insight is returned and cached/stored for immediate retrieval when the user views the "AI Analysis" tab.
