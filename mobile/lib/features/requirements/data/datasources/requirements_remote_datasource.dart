import '../../../../core/network/api_client.dart';

abstract class RequirementsRemoteDataSource {
  Future<Map<String, dynamic>> getRequirements(Map<String, dynamic> params);
  Future<Map<String, dynamic>> getById(String id);
  Future<Map<String, dynamic>> create(Map<String, dynamic> data);
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
  Future<void> accept(String id);
  Future<void> cancel(String id, String reason);
  Future<void> setStatus(String id, String status);
  Future<Map<String, dynamic>> getMy({String? status});
  Future<Map<String, dynamic>> getAcceptedByMe();
  Future<Map<String, dynamic>> getAssignedToMe();
  Future<void> assignDriver(String id, String driverId);
  Future<void> unassignDriver(String id);
}

class RequirementsRemoteDataSourceImpl implements RequirementsRemoteDataSource {
  final ApiClient apiClient;
  RequirementsRemoteDataSourceImpl(this.apiClient);

  @override
  Future<Map<String, dynamic>> getRequirements(Map<String, dynamic> params) async {
    final res = await apiClient.get('/requirements', params: params);
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getById(String id) async {
    final res = await apiClient.get('/requirements/$id');
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final res = await apiClient.post('/requirements', data: data);
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    final res = await apiClient.put('/requirements/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<void> delete(String id) async {
    await apiClient.delete('/requirements/$id');
  }

  @override
  Future<void> accept(String id) async {
    await apiClient.post('/requirements/$id/accept');
  }

  @override
  Future<void> cancel(String id, String reason) async {
    await apiClient.post('/requirements/$id/cancel', data: {'reason': reason});
  }

  @override
  Future<void> setStatus(String id, String status) async {
    await apiClient.post('/requirements/$id/status', data: {'status': status});
  }

  @override
  Future<Map<String, dynamic>> getMy({String? status}) async {
    final params = status != null ? {'status': status} : <String, dynamic>{};
    final res = await apiClient.get('/requirements/my', params: params);
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getAcceptedByMe() async {
    final res = await apiClient.get('/requirements/accepted-by-me');
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getAssignedToMe() async {
    final res = await apiClient.get('/requirements/assigned-to-me');
    return res.data as Map<String, dynamic>;
  }

  @override
  Future<void> assignDriver(String id, String driverId) async {
    await apiClient.post('/requirements/$id/assign', data: {'driverId': driverId});
  }

  @override
  Future<void> unassignDriver(String id) async {
    await apiClient.post('/requirements/$id/unassign');
  }
}
