#  Backend Architecture & Design

## 1. Microservices Architecture (마이크로서비스 아키텍처)

FSP 백엔드는 느슨하게 결합된(Loosely Coupled) 마이크로서비스 시스템으로 설계되었으며, Docker Compose를 통해 오케스트레이션됩니다. 이를 통해 각 컴포넌트의 독립적인 확장과 유지보수가 가능합니다.

`mermaid
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
`

---

## 2. Service Communication (서비스 간 통신)

### Gateway Pattern (게이트웨이 패턴)
- **역할**: 게이트웨이는 클라이언트의 단일 진실 공급원(Single Source of Truth) 역할을 합니다. CORS 처리, 인증(예정), 요청 라우팅을 담당합니다.
- **장점**: 클라이언트는 내부 마이크로서비스의 포트나 IP 주소를 알 필요가 없습니다.

### Polyglot Services (Dart + Python)
- **Dart**: 강력한 타입 시스템과 성능을 활용하여 주요 비즈니스 로직(백테스트, 마켓)에 사용됩니다.
- **Python**: 풍부한 금융 라이브러리 생태계(yfinance, pandas)를 활용하기 위해 Price Fetcher 서비스에 사용됩니다.
- **서비스 간 통신**: Docker 네트워크 내부에서 HTTP REST API를 통해 통신합니다.

---

## 3. Data Flow: Backtest Execution (백테스트 실행 흐름)

1.  **요청 (Request)**: 게이트웨이가 종목과 비중이 포함된 백테스트 요청을 수신합니다.
2.  **데이터 확인 (Data Check)**: 백테스트 서비스가 마켓 서비스에 과거 데이터를 요청합니다.
3.  **수집/캐싱 (Fetch/Cache)**: 
    - 마켓 서비스가 Redis 캐시를 확인합니다.
    - 캐시 미스(Miss) 시, Python Price Fetcher를 호출합니다.
    - Price Fetcher가 Yahoo Finance에서 데이터를 다운로드합니다.
4.  **계산 (Compute)**: 백테스트 서비스가 일별 수익률, CAGR, MDD를 계산합니다.
5.  **응답 (Response)**: 결과가 게이트웨이를 거쳐 클라이언트로 반환됩니다.

---

## 4. AI Analysis Pipeline (AI 분석 파이프라인)

사용자 대기 시간을 최소화하기 위한 전략:
1.  **비동기 트리거 (Async Trigger)**: 백테스트가 완료되는 즉시, 클라이언트는 AI 분석 요청을 **미리 시작(Prefetching)**합니다.
2.  **처리 (Processing)**: AI 서비스가 성과 지표를 포함한 프롬프트를 구성하여 LLM에 전송합니다.
3.  **결과 (Result)**: 텍스트 인사이트가 반환되며, 사용자가 "AI 분석" 탭을 볼 때 즉시 제공될 수 있도록 준비됩니다.
