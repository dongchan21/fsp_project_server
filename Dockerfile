# Use latest stable Dart SDK
FROM dart:stable AS build

# Resolve app dependencies
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

# Copy app source code
COPY . .
# Ensure packages are available
RUN dart pub get --offline

# Build the server executable
RUN dart compile exe bin/fsp_server.dart -o bin/server

# Build minimal serving image
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server
COPY --from=build /app/.env /app/.env

# Expose port
EXPOSE 8080

# Start server
CMD ["/app/bin/server"]
