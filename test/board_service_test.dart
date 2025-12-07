import 'dart:convert';
import 'package:test/test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:postgres/postgres.dart';
import 'package:fsp_server/services/board_service.dart';

import 'board_service_test.mocks.dart';

@GenerateMocks([PostgreSQLConnection, PostgreSQLResultRow])
void main() {
  late MockPostgreSQLConnection mockConnection;

  setUp(() {
    mockConnection = MockPostgreSQLConnection();
  });

  group('BoardService', () {
    group('createPost', () {
      test('succeeds', () async {
        when(mockConnection.query(
          any,
          substitutionValues: anyNamed('substitutionValues'),
        )).thenAnswer((_) async => FakePostgreSQLResult([]));

        final result = await BoardService.createPost(
          1,
          'Test Title',
          'Test Content',
          {'symbol': 'AAPL'},
          connection: mockConnection,
        );

        expect(result['message'], 'Post created successfully');
        
        verify(mockConnection.query(
          argThat(contains('INSERT INTO posts')),
          substitutionValues: argThat(allOf(
            containsPair('userId', 1),
            containsPair('title', 'Test Title'),
            containsPair('content', 'Test Content'),
            containsPair('portfolioData', jsonEncode({'symbol': 'AAPL'})),
          ), named: 'substitutionValues'),
        )).called(1);
      });
    });

    group('getPosts', () {
      test('returns list of posts', () async {
        final mockRow1 = MockPostgreSQLResultRow();
        when(mockRow1[0]).thenReturn(1);
        when(mockRow1[1]).thenReturn('Title 1');
        when(mockRow1[2]).thenReturn('Content 1');
        when(mockRow1[3]).thenReturn(jsonEncode({'symbol': 'AAPL'}));
        when(mockRow1[4]).thenReturn(DateTime.parse('2023-01-01 12:00:00'));
        when(mockRow1[5]).thenReturn('User 1');

        final mockRow2 = MockPostgreSQLResultRow();
        when(mockRow2[0]).thenReturn(2);
        when(mockRow2[1]).thenReturn('Title 2');
        when(mockRow2[2]).thenReturn('Content 2');
        when(mockRow2[3]).thenReturn({'symbol': 'GOOGL'}); // 이미 맵 형태
        when(mockRow2[4]).thenReturn(DateTime.parse('2023-01-02 12:00:00'));
        when(mockRow2[5]).thenReturn('User 2');

        when(mockConnection.query(any)).thenAnswer((_) async => FakePostgreSQLResult([mockRow1, mockRow2]));

        final results = await BoardService.getPosts(connection: mockConnection);

        expect(results.length, 2);
        expect(results[0]['id'], 1);
        expect(results[0]['portfolio_data'], {'symbol': 'AAPL'});
        expect(results[1]['id'], 2);
        expect(results[1]['portfolio_data'], {'symbol': 'GOOGL'});
      });
    });

    group('getPost', () {
      test('returns post when found', () async {
        final mockRow = MockPostgreSQLResultRow();
        when(mockRow[0]).thenReturn(1);
        when(mockRow[1]).thenReturn('Title');
        when(mockRow[2]).thenReturn('Content');
        when(mockRow[3]).thenReturn(jsonEncode({'symbol': 'AAPL'}));
        when(mockRow[4]).thenReturn(DateTime.parse('2023-01-01 12:00:00'));
        when(mockRow[5]).thenReturn('User');
        when(mockRow[6]).thenReturn(100); // user_id

        when(mockConnection.query(
          any,
          substitutionValues: anyNamed('substitutionValues'),
        )).thenAnswer((_) async => FakePostgreSQLResult([mockRow]));

        final result = await BoardService.getPost(1, connection: mockConnection);

        expect(result, isNotNull);
        expect(result!['id'], 1);
        expect(result['title'], 'Title');
        expect(result['user_id'], 100);
      });

      test('returns null when not found', () async {
        when(mockConnection.query(
          any,
          substitutionValues: anyNamed('substitutionValues'),
        )).thenAnswer((_) async => FakePostgreSQLResult([]));

        final result = await BoardService.getPost(999, connection: mockConnection);

        expect(result, isNull);
      });
    });

    group('deletePost', () {
      test('succeeds', () async {
        when(mockConnection.query(
          any,
          substitutionValues: anyNamed('substitutionValues'),
        )).thenAnswer((_) async => FakePostgreSQLResult([]));

        await BoardService.deletePost(1, connection: mockConnection);

        verify(mockConnection.query(
          argThat(contains('DELETE FROM posts')),
          substitutionValues: {'id': 1},
        )).called(1);
      });
    });
  });
}

// Helper for mocking PostgreSQLResult which is a List
class FakePostgreSQLResult extends Fake implements PostgreSQLResult {
  final List<PostgreSQLResultRow> _rows;
  FakePostgreSQLResult(this._rows);

  @override
  Iterator<PostgreSQLResultRow> get iterator => _rows.iterator;

  @override
  List<T> map<T>(T Function(PostgreSQLResultRow e) f) => _rows.map(f).toList();
  
  @override
  bool get isEmpty => _rows.isEmpty;

  @override
  PostgreSQLResultRow get first => _rows.first;
  
  @override
  int get affectedRowCount => _rows.length;
}
