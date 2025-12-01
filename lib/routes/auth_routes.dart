import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/auth_service.dart';

class AuthRoutes {
  Router get router {
    final router = Router();

    router.post('/signup', (Request request) async {
      try {
        final payload = jsonDecode(await request.readAsString());
        final email = payload['email'];
        final password = payload['password'];
        final nickname = payload['nickname'];

        if (email == null || password == null || nickname == null) {
          return Response.badRequest(body: jsonEncode({'error': 'Missing fields'}));
        }

        final result = await AuthService.signup(email, password, nickname);
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    router.post('/login', (Request request) async {
      try {
        final payload = jsonDecode(await request.readAsString());
        final email = payload['email'];
        final password = payload['password'];

        if (email == null || password == null) {
          return Response.badRequest(body: jsonEncode({'error': 'Missing fields'}));
        }

        final result = await AuthService.login(email, password);
        return Response.ok(jsonEncode(result), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.forbidden(jsonEncode({'error': e.toString()}), headers: {'Content-Type': 'application/json'});
      }
    });

    return router;
  }
}
