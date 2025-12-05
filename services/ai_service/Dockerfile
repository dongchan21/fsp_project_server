FROM dart:3.9 AS build
WORKDIR /app

# Copy shared packages
COPY packages ./packages

# Copy service code
COPY services/ai_service ./services/ai_service

# Set working directory to service
WORKDIR /app/services/ai_service

RUN dart pub get

CMD ["dart", "run", "bin/server.dart"]
