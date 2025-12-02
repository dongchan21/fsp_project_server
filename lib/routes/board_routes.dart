import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../services/board_service.dart';

class BoardRoutes {
  // AuthService와 동일한 키 사용 (실제로는 환경변수 권장)
  static const String _secretKey = 'my_secret_key';

  Router get router {
    final router = Router();

    // 게시글 목록 조회 (인증 불필요)
    router.get('/', (Request request) async {
      try {
        final posts = await BoardService.getPosts();
        return Response.ok(jsonEncode(posts), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // 게시글 상세 조회 (인증 불필요)
    router.get('/<id>', (Request request, String id) async {
      try {
        final postId = int.tryParse(id);
        if (postId == null) return Response.badRequest(body: 'Invalid ID');

        final post = await BoardService.getPost(postId);
        if (post == null) return Response.notFound('Post not found');

        return Response.ok(jsonEncode(post), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // 게시글 작성 (인증 필요)
    router.post('/', (Request request) async {
      // 1. 토큰 검증
      final authHeader = request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden(jsonEncode({'error': 'Missing or invalid token'}));
      }

      final token = authHeader.substring(7);
      int userId;
      try {
        final jwt = JWT.verify(token, SecretKey(_secretKey));
        userId = jwt.payload['id'];
      } catch (e) {
        return Response.forbidden(jsonEncode({'error': 'Invalid token'}));
      }

      // 2. 게시글 작성
      try {
        final payload = jsonDecode(await request.readAsString());
        final title = payload['title'];
        final content = payload['content'];
        final portfolioData = payload['portfolioData'];

        if (title == null || content == null || portfolioData == null) {
          return Response.badRequest(body: jsonEncode({'error': 'Missing fields'}));
        }

        final result = await BoardService.createPost(userId, title, content, portfolioData);
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // 게시글 삭제 (인증 및 본인 확인 필요)
    router.delete('/<id>', (Request request, String id) async {
      // 1. 토큰 검증
      final authHeader = request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden(jsonEncode({'error': 'Missing or invalid token'}));
      }

      final token = authHeader.substring(7);
      int userId;
      try {
        final jwt = JWT.verify(token, SecretKey(_secretKey));
        userId = jwt.payload['id'];
      } catch (e) {
        return Response.forbidden(jsonEncode({'error': 'Invalid token'}));
      }

      // 2. 게시글 존재 및 작성자 확인
      try {
        final postId = int.tryParse(id);
        if (postId == null) return Response.badRequest(body: 'Invalid ID');

        final post = await BoardService.getPost(postId);
        if (post == null) return Response.notFound('Post not found');

        if (post['user_id'] != userId) {
          return Response.forbidden(jsonEncode({'error': 'Permission denied'}));
        }

        // 3. 삭제 실행
        await BoardService.deletePost(postId);
        return Response.ok(jsonEncode({'message': 'Post deleted successfully'}), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    return router;
  }
}
