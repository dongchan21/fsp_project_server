FROM dart:3.9 AS build
WORKDIR /app

# Copy shared packages
COPY packages ./packages

# Copy service code
COPY services/backtest_service ./services/backtest_service

# Set working directory to service
WORKDIR /app/services/backtest_service

RUN dart pub get
# (Optional) RUN dart test

CMD ["dart", "run", "bin/server.dart"]
