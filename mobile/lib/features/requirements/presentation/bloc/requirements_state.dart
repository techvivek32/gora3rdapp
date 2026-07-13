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
  final List<Map<String, dynamic>> myAccepted;
  final bool isLoadingMore;
  final bool hasMore;

  const RequirementsLoaded({
    required this.requirements,
    this.myAccepted = const [],
    this.isLoadingMore = false,
    this.hasMore = false,
  });

  RequirementsLoaded copyWith({
    List<Map<String, dynamic>>? requirements,
    List<Map<String, dynamic>>? myAccepted,
    bool? isLoadingMore,
    bool? hasMore,
  }) => RequirementsLoaded(
    requirements: requirements ?? this.requirements,
    myAccepted: myAccepted ?? this.myAccepted,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
  );

  @override
  List<Object?> get props => [requirements, myAccepted, isLoadingMore, hasMore];
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

class MyRequirementsLoaded extends RequirementsState {
  /// Requirements I posted.
  final List<Map<String, dynamic>> requirements;

  /// Requirements someone else assigned to me as the driver.
  final List<Map<String, dynamic>> assignedToMe;

  const MyRequirementsLoaded({
    required this.requirements,
    this.assignedToMe = const [],
  });

  @override
  List<Object?> get props => [requirements, assignedToMe];
}

/// Emitted after a successful assign so the page can show a confirmation.
class DriverAssigned extends RequirementsState {
  const DriverAssigned();
}
