import 'dart:io';
import 'package:postgres/postgres.dart';

class DbUtils {
  static PostgreSQLConnection? _connection;

  static Future<PostgreSQLConnection> getConnection() async {
    if (_connection != null && !_connection!.isClosed) {
      return _connection!;
    }

    final host = Platform.environment['POSTGRES_HOST'] ?? 'localhost';
    final port = int.parse(Platform.environment['POSTGRES_PORT'] ?? '5432');
    final database = Platform.environment['POSTGRES_DB'] ?? 'fsp';
    final username = Platform.environment['POSTGRES_USER'] ?? 'fsp';
    final password = Platform.environment['POSTGRES_PASSWORD'] ?? 'fsp';

    _connection = PostgreSQLConnection(
      host,
      port,
      database,
      username: username,
      password: password,
    );

    await _connection!.open();
    return _connection!;
  }

  static Future<void> initTables() async {
    final conn = await getConnection();

    // Users table
    await conn.query('''
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        nickname VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Posts table
    await conn.query('''
      CREATE TABLE IF NOT EXISTS posts (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        title VARCHAR(255) NOT NULL,
        content TEXT,
        portfolio_data JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }
}
