import 'dart:convert';
import '../utils/db_utils.dart';

class BoardService {
  // 게시글 작성
  static Future<Map<String, dynamic>> createPost(int userId, String title, String content, Map<String, dynamic> portfolioData) async {
    final conn = await DbUtils.getConnection();

    await conn.query(
      'INSERT INTO posts (user_id, title, content, portfolio_data) VALUES (@userId, @title, @content, @portfolioData)',
      substitutionValues: {
        'userId': userId,
        'title': title,
        'content': content,
        'portfolioData': jsonEncode(portfolioData), // JSONB에 저장하기 위해 문자열로 변환
      },
    );

    return {'message': 'Post created successfully'};
  }

  // 게시글 목록 조회
  static Future<List<Map<String, dynamic>>> getPosts() async {
    final conn = await DbUtils.getConnection();

    final results = await conn.query(
      '''
      SELECT p.id, p.title, p.content, p.portfolio_data, p.created_at, u.nickname 
      FROM posts p
      JOIN users u ON p.user_id = u.id
      ORDER BY p.created_at DESC
      '''
    );

    return results.map((row) {
      // row[3] (portfolio_data) 처리: String이면 Map으로 디코딩, 아니면 그대로 사용
      // postgres 드라이버 버전에 따라 JSONB가 String으로 올 수도 있고 Map으로 올 수도 있음
      var portfolioData = row[3];
      if (portfolioData is String) {
        try {
          portfolioData = jsonDecode(portfolioData);
        } catch (_) {}
      }

      return {
        'id': row[0],
        'title': row[1],
        'content': row[2],
        'portfolio_data': portfolioData, 
        'created_at': row[4].toString(),
        'author_name': row[5],
      };
    }).toList();
  }
  
  // 게시글 상세 조회
  static Future<Map<String, dynamic>?> getPost(int id) async {
    final conn = await DbUtils.getConnection();

    final results = await conn.query(
      '''
      SELECT p.id, p.title, p.content, p.portfolio_data, p.created_at, u.nickname 
      FROM posts p
      JOIN users u ON p.user_id = u.id
      WHERE p.id = @id
      ''',
      substitutionValues: {'id': id}
    );

    if (results.isEmpty) return null;

    final row = results.first;
    
    var portfolioData = row[3];
    if (portfolioData is String) {
      try {
        portfolioData = jsonDecode(portfolioData);
      } catch (_) {}
    }

    return {
      'id': row[0],
      'title': row[1],
      'content': row[2],
      'portfolio_data': portfolioData,
      'created_at': row[4].toString(),
      'author_name': row[5],
    };
  }
}
