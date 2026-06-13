import '../../../../core/network/api_client.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login(String identifier, String password, String? fcmToken);
  Future<Map<String, dynamic>> register(Map<String, dynamic> data);
  Future<Map<String, dynamic>> verifyOtp(String firebaseIdToken, String? fcmToken);
  Future<void> logout(String? fcmToken);
  Future<Map<String, dynamic>> refreshTokens(String userId, String refreshToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;
  AuthRemoteDataSourceImpl(this.apiClient);

  @override
  Future<Map<String, dynamic>> login(String identifier, String password, String? fcmToken) async {
    final response = await apiClient.post('/auth/login', data: {
      'identifier': identifier,
      'password': password,
      if (fcmToken != null) 'fcmToken': fcmToken,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final response = await apiClient.post('/auth/register', data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<Map<String, dynamic>> verifyOtp(String firebaseIdToken, String? fcmToken) async {
    final response = await apiClient.post('/auth/verify-otp', data: {
      'firebaseIdToken': firebaseIdToken,
      if (fcmToken != null) 'fcmToken': fcmToken,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<void> logout(String? fcmToken) async {
    await apiClient.post('/auth/logout', data: {'fcmToken': fcmToken});
  }

  @override
  Future<Map<String, dynamic>> refreshTokens(String userId, String refreshToken) async {
    final response = await apiClient.post('/auth/refresh', data: {
      'userId': userId,
      'refreshToken': refreshToken,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }
}
