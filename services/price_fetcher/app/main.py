import os
from datetime import datetime, date
from typing import List, Optional

import yfinance as yf
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
import psycopg
from psycopg.rows import dict_row

# Environment configuration
PG_HOST = os.getenv("POSTGRES_HOST", "localhost")
PG_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
PG_DB = os.getenv("POSTGRES_DB", "fsp")
PG_USER = os.getenv("POSTGRES_USER", "fsp")
PG_PASSWORD = os.getenv("POSTGRES_PASSWORD", "fsp")

app = FastAPI(title="Price Fetcher", version="1.0.0")

class PricePoint(BaseModel):
    date: date
    close: float

class LatestPrice(BaseModel):
    symbol: str
    date: datetime
    close: float

class HistoryResponse(BaseModel):
    symbol: str
    points: List[PricePoint]

class FirstDayHistoryResponse(BaseModel):
    symbol: str
    points: List[PricePoint]

SQL_CREATE_TABLE = """
CREATE TABLE IF NOT EXISTS price (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(10) NOT NULL,
    date DATE NOT NULL,
    close NUMERIC(10, 2) NOT NULL
);
"""

SQL_UPSERT = """
INSERT INTO price(symbol, date, close)
VALUES (%s, %s, %s)
ON CONFLICT (symbol, date) DO UPDATE SET close = EXCLUDED.close
"""

# Ensure required index/constraint exist (id primary key already assumed)
SQL_ENSURE_UNIQUE = """
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'price_symbol_date_idx'
  ) THEN
    CREATE UNIQUE INDEX price_symbol_date_idx ON price(symbol, date);
  END IF;
END$$;
"""

async def get_conn():
    return await psycopg.AsyncConnection.connect(
        host=PG_HOST,
        port=PG_PORT,
        dbname=PG_DB,
        user=PG_USER,
        password=PG_PASSWORD,
        row_factory=dict_row,
    )

async def check_saved(symbol: str, dt: date) -> bool:
    SQL_CHECK = """
    SELECT 1 FROM price
    WHERE symbol = %s AND date = %s
    LIMIT 1
    """
    async with await get_conn() as conn:
        async with conn.cursor() as cur:
            await cur.execute(SQL_CHECK, (symbol, dt))
            row = await cur.fetchone()
            return row is not None


@app.on_event("startup")
async def startup():
    print("🔵 [INIT] Starting Price Fetcher server...")

    # 1) PostgreSQL 연결 테스트
    print("🔵 [INIT] Checking PostgreSQL connection...")
    try:
        async with await get_conn() as conn:
            print("🟢 [DB] PostgreSQL connection successful!")
            
            async with conn.cursor() as cur:
                # 1) Ensure table exists
                print("🔵 [DB] Ensuring table 'price' exists...")
                await cur.execute(SQL_CREATE_TABLE)
                
                # 2) Unique index 생성 확인
                print("🔵 [DB] Ensuring unique index on price(symbol, date)...")
                await cur.execute(SQL_ENSURE_UNIQUE)
                print("🟢 [DB] Unique index OK!")
            # DDL 반영
            await conn.commit()

    except Exception as e:
        print(f"🔴 [DB] PostgreSQL connection FAILED: {e}")

    print("🟢 [INIT] Server startup complete.")

@app.get("/prices/latest/{symbol}", response_model=LatestPrice)
async def latest_price(symbol: str):
    s = symbol.upper().strip()
    try:
        ticker = yf.Ticker(s)
        # Try fast path
        fast = getattr(ticker, "fast_info", None)
        if fast and fast.get("lastPrice"):
            close = float(fast["lastPrice"])
            dt = datetime.utcnow()
        else:
            hist = ticker.history(period="1d")
            if hist.empty:
                raise HTTPException(status_code=404, detail="no_data")
            close = float(hist["Close"].iloc[-1])
            dt = hist.index[-1].to_pydatetime()
        async with await get_conn() as conn:
            async with conn.cursor() as cur:
                await cur.execute(SQL_UPSERT, (s, dt.date(), close))
            # 커밋하여 다른 커넥션에서도 조회 가능하도록 보장
            await conn.commit()

        saved = await check_saved(s, dt.date())
        if not saved:
            print(f"🔴 [DB] Save verification failed for {s} {dt.date()}")
        else:
            print(f"🟢 [DB] Saved successfully: {s} {dt.date()} = {close}")

                
        return LatestPrice(symbol=s, date=dt, close=close)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"fetch_failed: {e}")

@app.get("/prices/history/{symbol}", response_model=HistoryResponse)
async def history_price(symbol: str,
                        start: date = Query(..., description="Inclusive start date YYYY-MM-DD"),
                        end: date = Query(..., description="Inclusive end date YYYY-MM-DD"),
                        interval: str = Query("1mo", pattern="^(1d|1wk|1mo)$")):
    if start > end:
        raise HTTPException(status_code=400, detail="start_after_end")
    s = symbol.upper().strip()
    try:
        data = yf.download(s, start=start.isoformat(), end=(end.isoformat()), interval=interval, progress=False)
        if data.empty:
            raise HTTPException(status_code=404, detail="no_data")
        points: List[PricePoint] = []
        async with await get_conn() as conn:
            async with conn.cursor() as cur:
                for idx, row in data.iterrows():
                    dt = idx.to_pydatetime().date()
                    # Upsert monthly/daily row
                    close = float(row['Close'])
                    await cur.execute(SQL_UPSERT, (s, dt, close))
                    points.append(PricePoint(date=dt, close=close))
            # 일괄 반영
            await conn.commit()
        return HistoryResponse(symbol=s, points=points)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"history_failed: {e}")

@app.get("/prices/history_firstday/{symbol}", response_model=FirstDayHistoryResponse)
async def history_firstday(symbol: str,
                           start: date = Query(..., description="Inclusive start date YYYY-MM-DD"),
                           end: date = Query(..., description="Inclusive end date YYYY-MM-DD")):
    if start > end:
        raise HTTPException(status_code=400, detail="start_after_end")
    s = symbol.upper().strip()
    try:
        # Fetch full daily range once
        data = yf.download(s, start=start.isoformat(), end=end.isoformat(), interval='1d', progress=False)
        if data.empty:
            raise HTTPException(status_code=404, detail="no_data")
        # Group by year-month and take earliest trading day
        grouped = {}
        for idx, row in data.iterrows():
            dt = idx.to_pydatetime().date()
            ym = dt.strftime('%Y-%m')
            if ym not in grouped or dt < grouped[ym]['date']:
                grouped[ym] = {'date': dt, 'close': float(row['Close'])}
        points: List[PricePoint] = [PricePoint(date=v['date'], close=v['close']) for v in sorted(grouped.values(), key=lambda x: x['date'])]
        async with await get_conn() as conn:
            async with conn.cursor() as cur:
                for p in points:
                    await cur.execute(SQL_UPSERT, (s, p.date, p.close))
            await conn.commit()
        return FirstDayHistoryResponse(symbol=s, points=points)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"history_firstday_failed: {e}")

@app.get("/healthz")
async def healthz():
    return {"status": "ok"}

@app.get("/readyz")
async def readyz():
    # simple readiness check: can we connect?
    try:
        async with await get_conn() as _:
            return {"status": "ready"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"db_unavailable: {e}")
