FROM dart:3.9 AS build
WORKDIR /app

# Copy shared packages
COPY packages ./packages

# Copy service code
COPY services/market_service ./services/market_service

# Set working directory to service
WORKDIR /app/services/market_service

RUN dart pub get

CMD ["dart", "run", "bin/server.dart"]
