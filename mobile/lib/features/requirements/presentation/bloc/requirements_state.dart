part of 'requirements_bloc.dart';

abstract class RequirementsState extends Equatable {
  const RequirementsState();
  @override
  List<Object?> get props => [];
}

class RequirementsInitial extends RequirementsState {}
class RequirementsLoading extends RequirementsState {}

class RequirementsLoaded extends RequirementsState {
  final List<Map<String, dynamic>> requirements;
  final bool isLoadingMore;
  final bool hasMore;

  const RequirementsLoaded({
    required this.requirements,
    this.isLoadingMore = false,
    this.hasMore = false,
  });

  RequirementsLoaded copyWith({
    List<Map<String, dynamic>>? requirements,
    bool? isLoadingMore,
    bool? hasMore,
  }) => RequirementsLoaded(
    requirements: requirements ?? this.requirements,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
  );

  @override
  List<Object?> get props => [requirements, isLoadingMore, hasMore];
}

class RequirementsError extends RequirementsState {
  final String message;
  const RequirementsError({required this.message});
  @override
  List<Object?> get props => [message];
}

class RequirementCreated extends RequirementsState {
  final Map<String, dynamic> requirement;
  const RequirementCreated({required this.requirement});
}

class RequirementDetailLoaded extends RequirementsState {
  final Map<String, dynamic> requirement;
  const RequirementDetailLoaded({required this.requirement});
  @override
  List<Object?> get props => [requirement];
}

class RequirementAccepted extends RequirementsState {}

class RequirementUpdated extends RequirementsState {
  final Map<String, dynamic> requirement;
  const RequirementUpdated({required this.requirement});
  @override
  List<Object?> get props => [requirement];
}

class RequirementCancelled extends RequirementsState {}
