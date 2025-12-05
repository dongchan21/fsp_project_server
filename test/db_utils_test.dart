import 'package:test/test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:postgres/postgres.dart';
import 'package:fsp_server/utils/db_utils.dart';

import 'db_utils_test.mocks.dart';

@GenerateMocks([PostgreSQLConnection, PostgreSQLResult])
void main() {
  late MockPostgreSQLConnection mockConnection;
  late MockPostgreSQLResult mockResult;

  setUp(() {
    mockConnection = MockPostgreSQLConnection();
    mockResult = MockPostgreSQLResult();
  });

  group('DbUtils', () {
    group('initTables', () {
      test('executes CREATE TABLE queries', () async {
        when(mockConnection.query(any)).thenAnswer((_) async => mockResult);

        await DbUtils.initTables(connection: mockConnection);

        // Verify that query was called 3 times (users, posts, backtest_history)
        verify(mockConnection.query(argThat(contains('CREATE TABLE IF NOT EXISTS users')))).called(1);
        verify(mockConnection.query(argThat(contains('CREATE TABLE IF NOT EXISTS posts')))).called(1);
        verify(mockConnection.query(argThat(contains('CREATE TABLE IF NOT EXISTS backtest_history')))).called(1);
      });
    });
  });
}
