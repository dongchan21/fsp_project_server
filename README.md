A sample command-line application with an entrypoint in `bin/`, library code
in `lib/`, and example unit test in `test/`.

# Python 서비스 (Windows)

cd services/price_fetcher
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --port 8090 --reload

# Market 서비스

cd ..\market_service
dart pub get
dart run bin/server.dart

# 테스트: 캐시/DB miss -> 외부 fetch -> upsert

curl http://localhost:8090/prices/latest/AAPL
Invoke-RestMethod -Uri "http://localhost:8081/v1/price/AAPL"
docker exec -it redis redis-cli GET price:AAPL
