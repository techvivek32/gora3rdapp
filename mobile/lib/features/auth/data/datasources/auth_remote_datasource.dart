import '../../../../core/network/api_client.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login(String identifier, String password, String? fcmToken);
  Future<Map<String, dynamic>> loginSendOtp(String mobile);
  Future<Map<String, dynamic>> loginVerifyOtp(String mobile, String otp, String? fcmToken);
  Future<Map<String, dynamic>> register(Map<String, dynamic> data);
  Future<Map<String, dynamic>> verifyOtp(String firebaseIdToken, String? fcmToken);
  Future<void> logout(String? fcmToken);
  Future<Map<String, dynamic>> refreshTokens(String userId, String refreshToken);
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data);
  Future<Map<String, dynamic>> getProfile();
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
  Future<Map<String, dynamic>> loginSendOtp(String mobile) async {
    final response = await apiClient.post('/auth/login/send-otp', data: {'mobile': mobile});
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<Map<String, dynamic>> loginVerifyOtp(String mobile, String otp, String? fcmToken) async {
    final response = await apiClient.post('/auth/login/verify-otp', data: {
      'mobile': mobile,
      'otp': otp,
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

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await apiClient.put('/users/profile', data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<Map<String, dynamic>> getProfile() async {
    final response = await apiClient.get('/users/profile');
    return Map<String, dynamic>.from(response.data as Map);
  }
}
