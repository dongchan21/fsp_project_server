import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../utils/db_utils.dart';

import 'package:postgres/postgres.dart';

class AuthService {
  static const String _secretKey = 'my_secret_key'; // 실제 운영 시에는 환경변수로 관리해야 함

  // 회원가입
  static Future<Map<String, dynamic>> signup(String email, String password, String nickname, {PostgreSQLConnection? connection}) async {
    final conn = connection ?? await DbUtils.getConnection();

    // 이메일 중복 체크
    final check = await conn.query('SELECT id FROM users WHERE email = @email', substitutionValues: {'email': email});
    if (check.isNotEmpty) {
      throw Exception('Email already exists');
    }

    // 비밀번호 해시
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    final passwordHash = digest.toString();

    // 사용자 생성
    await conn.query(
      'INSERT INTO users (email, password_hash, nickname) VALUES (@email, @hash, @nickname)',
      substitutionValues: {
        'email': email,
        'hash': passwordHash,
        'nickname': nickname,
      },
    );

    return {'message': 'User created successfully'};
  }

  // 로그인
  static Future<Map<String, dynamic>> login(String email, String password, {PostgreSQLConnection? connection}) async {
    final conn = connection ?? await DbUtils.getConnection();

    // 사용자 조회
    final result = await conn.query(
      'SELECT id, password_hash, nickname FROM users WHERE email = @email',
      substitutionValues: {'email': email},
    );

    if (result.isEmpty) {
      throw Exception('Invalid email or password');
    }

    final row = result.first;
    final id = row[0] as int;
    final storedHash = row[1] as String;
    final nickname = row[2] as String;

    // 비밀번호 검증
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    if (digest.toString() != storedHash) {
      throw Exception('Invalid email or password');
    }

    // JWT 토큰 생성
    final jwt = JWT(
      {
        'id': id,
        'email': email,
        'nickname': nickname,
      },
    );

    final token = jwt.sign(SecretKey(_secretKey));

    return {
      'token': token,
      'user': {
        'id': id,
        'email': email,
        'nickname': nickname,
      }
    };
  }
}
