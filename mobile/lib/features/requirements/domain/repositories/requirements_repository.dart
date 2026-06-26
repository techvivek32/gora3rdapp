import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

abstract class RequirementsRepository {
  Future<Either<Failure, Map<String, dynamic>>> getRequirements({
    int page = 1,
    int limit = 20,
    String? search,
    Map<String, dynamic>? filters,
  });

  Future<Either<Failure, Map<String, dynamic>>> getRequirementById(String id);
  Future<Either<Failure, Map<String, dynamic>>> createRequirement(Map<String, dynamic> data);
  Future<Either<Failure, Map<String, dynamic>>> updateRequirement(String id, Map<String, dynamic> data);
  Future<Either<Failure, void>> deleteRequirement(String id);
  Future<Either<Failure, void>> acceptRequirement(String id);
  Future<Either<Failure, void>> cancelRequirement(String id, String reason);
  Future<Either<Failure, void>> setStatus(String id, String status);
  Future<Either<Failure, Map<String, dynamic>>> getMyRequirements({String? status});
  Future<Either<Failure, Map<String, dynamic>>> getAcceptedByMe();
}
