import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/vehicles_repository.dart';

class VehiclesRepositoryImpl implements VehiclesRepository {
  final ApiClient apiClient;
  VehiclesRepositoryImpl(this.apiClient);

  @override
  Future<Either<Failure, Map<String, dynamic>>> getVehicles({int page = 1, Map<String, dynamic>? filters}) async {
    try {
      final res = await apiClient.get('/available-vehicles', params: {'page': page, ...?filters});
      return Right(res.data as Map<String, dynamic>);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
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
