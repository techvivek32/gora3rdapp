import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/vehicles_repository.dart';

class VehiclesRepositoryImpl implements VehiclesRepository {
  final ApiClient apiClient;
  VehiclesRepositoryImpl(this.apiClient);

  // Listings already reported as "seen" this session — dedupe across refreshes.
  static final Set<String> _reportedViews = {};

  @override
  Future<Either<Failure, Map<String, dynamic>>> getVehicles({int page = 1, Map<String, dynamic>? filters}) async {
    try {
      final res = await apiClient.get('/available-vehicles', params: {'page': page, 'limit': 50, ...?filters});
      final data = res.data as Map<String, dynamic>;
      unawaited(_reportViews(data['data']));
      return Right(data);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Reports which listings appeared in the user's feed so the admin "Views"
  /// count is real. Fire-and-forget — never affects the feed result.
  Future<void> _reportViews(dynamic list) async {
    if (list is! List) return;
    final ids = <String>[];
    for (final item in list) {
      final id = (item is Map ? item['_id'] : null)?.toString() ?? '';
      if (id.isNotEmpty && _reportedViews.add(id)) ids.add(id);
    }
    if (ids.isEmpty) return;
    try {
      await apiClient.post('/available-vehicles/mark-views', data: {'ids': ids});
    } catch (_) {
      _reportedViews.removeAll(ids);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getVehicleById(String id) async {
    try {
      final res = await apiClient.get('/available-vehicles/$id');
      return Right(res.data as Map<String, dynamic>);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createVehicle(Map<String, dynamic> data) async {
    try {
      final res = await apiClient.post('/available-vehicles', data: data);
      return Right(res.data as Map<String, dynamic>);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> updateVehicle(String id, Map<String, dynamic> data) async {
    try {
      final res = await apiClient.put('/available-vehicles/$id', data: data);
      return Right(res.data as Map<String, dynamic>);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteVehicle(String id) async {
    try {
      await apiClient.delete('/available-vehicles/$id');
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelVehicle(String id, String reason) async {
    try {
      await apiClient.post('/available-vehicles/$id/cancel', data: {'reason': reason});
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setStatus(String id, String status) async {
    try {
      await apiClient.post('/available-vehicles/$id/status', data: {'status': status});
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getMyVehicles() async {
    try {
      final res = await apiClient.get('/available-vehicles/my');
      return Right(res.data as Map<String, dynamic>);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> acceptVehicle(String id) async {
    try {
      final res = await apiClient.post('/available-vehicles/$id/accept');
      return Right(res.data as Map<String, dynamic>);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getAcceptedByMe() async {
    try {
      final res = await apiClient.get('/available-vehicles/accepted-by-me');
      return Right(res.data as Map<String, dynamic>);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
