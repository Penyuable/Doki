import '../../core/network/api_client.dart';
import '../../domain/models/user_model.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthSession> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/register',
      auth: false,
      body: <String, dynamic>{
        'email': email.trim(),
        'username': username.trim(),
        'password': password,
      },
    );
    final session = AuthSession.fromJson(data);
    await _api.applySession(session);
    return session;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/login',
      auth: false,
      body: <String, dynamic>{
        'email': email.trim(),
        'password': password,
      },
    );
    final session = AuthSession.fromJson(data);
    await _api.applySession(session);
    return session;
  }

  Future<MeData> me() async {
    final data = await _api.get('/auth/me');
    return MeData.fromJson(data);
  }

  Future<void> logout(String refreshToken) async {
    if (refreshToken.isNotEmpty) {
      await _api.post(
        '/auth/logout',
        body: <String, dynamic>{'refreshToken': refreshToken},
      );
    }
    await _api.clearSession();
  }
}
