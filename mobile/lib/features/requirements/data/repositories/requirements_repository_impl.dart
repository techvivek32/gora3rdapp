import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/requirements_repository.dart';
import '../datasources/requirements_remote_datasource.dart';

class RequirementsRepositoryImpl implements RequirementsRepository {
  final RequirementsRemoteDataSource remote;
  RequirementsRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, Map<String, dynamic>>> getRequirements({int page = 1, int limit = 2000, String? search, Map<String, dynamic>? filters}) async {
    try {
      final params = {'page': page, 'limit': limit, if (search != null) 'search': search, ...?filters};
      final result = await remote.getRequirements(params.map((k, v) => MapEntry(k, v.toString())));
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getRequirementById(String id) async {
    try {
      final result = await remote.getById(id);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createRequirement(Map<String, dynamic> data) async {
    try {
      final result = await remote.create(data);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> updateRequirement(String id, Map<String, dynamic> data) async {
    try {
      final result = await remote.update(id, data);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRequirement(String id) async {
    try {
      await remote.delete(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> acceptRequirement(String id) async {
    try {
      await remote.accept(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelRequirement(String id, String reason) async {
    try {
      await remote.cancel(id, reason);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setStatus(String id, String status) async {
    try {
      await remote.setStatus(id, status);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getMyRequirements({String? status}) async {
    try {
      final result = await remote.getMy(status: status);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getAcceptedByMe() async {
    try {
      final result = await remote.getAcceptedByMe();
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getAssignedToMe() async {
    try {
      final result = await remote.getAssignedToMe();
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> assignDriver(String id, String driverId) async {
    try {
      await remote.assignDriver(id, driverId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unassignDriver(String id) async {
    try {
      await remote.unassignDriver(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
