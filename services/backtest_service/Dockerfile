FROM dart:3.9 AS build
WORKDIR /app
COPY . .
RUN dart pub get
# (Optional) RUN dart test

CMD ["dart", "run", "bin/server.dart"]
