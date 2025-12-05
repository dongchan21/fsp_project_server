import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:postgres/postgres.dart';
import 'package:fsp_server/services/auth_service.dart';

import 'auth_service_test.mocks.dart';

@GenerateMocks([PostgreSQLConnection, PostgreSQLResult, PostgreSQLResultRow])
void main() {
  late MockPostgreSQLConnection mockConnection;
  late MockPostgreSQLResult mockResult;

  setUp(() {
    mockConnection = MockPostgreSQLConnection();
    mockResult = MockPostgreSQLResult();
  });

  group('AuthService', () {
    group('signup', () {
      test('succeeds when email is unique', () async {
        // Mock email check returns empty result
        when(mockConnection.query(
          any,
          substitutionValues: anyNamed('substitutionValues'),
        )).thenAnswer((_) async => mockResult);
        
        when(mockResult.isNotEmpty).thenReturn(false);
        when(mockResult.isEmpty).thenReturn(true);

        final result = await AuthService.signup(
          'test@example.com',
          'password123',
          'nickname',
          connection: mockConnection,
        );

        expect(result['message'], 'User created successfully');
        
        // Verify insert was called
        verify(mockConnection.query(
          argThat(contains('INSERT INTO users')),
          substitutionValues: argThat(allOf(
            containsPair('email', 'test@example.com'),
            containsPair('nickname', 'nickname'),
            contains('hash'),
          ), named: 'substitutionValues'),
        )).called(1);
      });

      test('fails when email already exists', () async {
        // Mock email check returns non-empty result
        when(mockConnection.query(
          any,
          substitutionValues: anyNamed('substitutionValues'),
        )).thenAnswer((_) async => mockResult);

        when(mockResult.isNotEmpty).thenReturn(true);

        expect(
          () => AuthService.signup(
            'existing@example.com',
            'password123',
            'nickname',
            connection: mockConnection,
          ),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Email already exists'))),
        );
      });
    });

    group('login', () {
      test('succeeds with correct credentials', () async {
        final password = 'password123';
        final bytes = utf8.encode(password);
        final digest = sha256.convert(bytes);
        final hash = digest.toString();

        // Mock user lookup returns a row
        final mockRow = MockPostgreSQLResultRow();
        when(mockRow[0]).thenReturn(1); // id
        when(mockRow[1]).thenReturn(hash); // password_hash
        when(mockRow[2]).thenReturn('nickname'); // nickname

        when(mockConnection.query(
          any,
          substitutionValues: anyNamed('substitutionValues'),
        )).thenAnswer((_) async => mockResult);

        when(mockResult.isEmpty).thenReturn(false);
        when(mockResult.first).thenReturn(mockRow);

        final result = await AuthService.login(
          'test@example.com',
          password,
          connection: mockConnection,
        );

        expect(result['token'], isNotNull);
        expect(result['user']['email'], 'test@example.com');
      });

      test('fails with incorrect password', () async {
        final correctHash = 'some_hash';

        // Mock user lookup returns a row
        final mockRow = MockPostgreSQLResultRow();
        when(mockRow[0]).thenReturn(1);
        when(mockRow[1]).thenReturn(correctHash);
        when(mockRow[2]).thenReturn('nickname');

        when(mockConnection.query(
          any,
          substitutionValues: anyNamed('substitutionValues'),
        )).thenAnswer((_) async => mockResult);

        when(mockResult.isEmpty).thenReturn(false);
        when(mockResult.first).thenReturn(mockRow);

        expect(
          () => AuthService.login(
            'test@example.com',
            'wrong_password',
            connection: mockConnection,
          ),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Invalid email or password'))),
        );
      });

      test('fails when user not found', () async {
        when(mockConnection.query(
          any,
          substitutionValues: anyNamed('substitutionValues'),
        )).thenAnswer((_) async => mockResult);

        when(mockResult.isEmpty).thenReturn(true);

        expect(
          () => AuthService.login(
            'unknown@example.com',
            'password',
            connection: mockConnection,
          ),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Invalid email or password'))),
        );
      });
    });
  });
}
