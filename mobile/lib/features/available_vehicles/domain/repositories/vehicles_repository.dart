import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

abstract class VehiclesRepository {
  Future<Either<Failure, Map<String, dynamic>>> getVehicles({int page = 1, Map<String, dynamic>? filters});
  Future<Either<Failure, Map<String, dynamic>>> getVehicleById(String id);
  Future<Either<Failure, Map<String, dynamic>>> createVehicle(Map<String, dynamic> data);
  Future<Either<Failure, Map<String, dynamic>>> updateVehicle(String id, Map<String, dynamic> data);
  Future<Either<Failure, void>> deleteVehicle(String id);
  Future<Either<Failure, Map<String, dynamic>>> getMyVehicles();
}
