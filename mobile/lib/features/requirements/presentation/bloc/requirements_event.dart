part of 'requirements_bloc.dart';

abstract class RequirementsEvent extends Equatable {
  const RequirementsEvent();
  @override
  List<Object?> get props => [];
}

class LoadRequirementsEvent extends RequirementsEvent {
  final Map<String, dynamic>? filters;
  const LoadRequirementsEvent({this.filters});
}

class LoadMoreRequirementsEvent extends RequirementsEvent {}

class SearchRequirementsEvent extends RequirementsEvent {
  final String query;
  const SearchRequirementsEvent({required this.query});
}

class FilterRequirementsEvent extends RequirementsEvent {
  final Map<String, dynamic> filters;
  const FilterRequirementsEvent({required this.filters});
}

class CreateRequirementEvent extends RequirementsEvent {
  final Map<String, dynamic> data;
  const CreateRequirementEvent({required this.data});
}

class DeleteRequirementEvent extends RequirementsEvent {
  final String id;
  const DeleteRequirementEvent({required this.id});
}

class LoadRequirementDetailEvent extends RequirementsEvent {
  final String id;
  const LoadRequirementDetailEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class AcceptRequirementEvent extends RequirementsEvent {
  final String id;
  const AcceptRequirementEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class UpdateRequirementEvent extends RequirementsEvent {
  final String id;
  final Map<String, dynamic> data;
  const UpdateRequirementEvent({required this.id, required this.data});
  @override
  List<Object?> get props => [id, data];
}

class CancelRequirementEvent extends RequirementsEvent {
  final String id;
  final String reason;
  const CancelRequirementEvent({required this.id, required this.reason});
  @override
  List<Object?> get props => [id, reason];
}

class LoadMyRequirementsEvent extends RequirementsEvent {
  const LoadMyRequirementsEvent();
}
