import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/requirements_repository.dart';

part 'requirements_event.dart';
part 'requirements_state.dart';

class RequirementsBloc extends Bloc<RequirementsEvent, RequirementsState> {
  final RequirementsRepository repository;
  int _currentPage = 1;
  bool _hasMore = true;

  RequirementsBloc(this.repository) : super(RequirementsInitial()) {
    on<LoadRequirementsEvent>(_onLoad);
    on<LoadMoreRequirementsEvent>(_onLoadMore);
    on<SearchRequirementsEvent>(_onSearch);
    on<FilterRequirementsEvent>(_onFilter);
    on<CreateRequirementEvent>(_onCreate);
    on<DeleteRequirementEvent>(_onDelete);
    on<LoadRequirementDetailEvent>(_onLoadDetail);
    on<AcceptRequirementEvent>(_onAccept);
    on<UpdateRequirementEvent>(_onUpdate);
    on<CancelRequirementEvent>(_onCancel);
    on<SetRequirementStatusEvent>(_onSetStatus);
    on<LoadMyRequirementsEvent>(_onLoadMy);
  }

  Future<void> _onSetStatus(SetRequirementStatusEvent event, Emitter<RequirementsState> emit) async {
    final result = await repository.setStatus(event.id, event.status);
    result.fold(
      (f) => emit(RequirementsError(message: f.message)),
      (_) => add(const LoadMyRequirementsEvent()),
    );
  }

  Future<void> _onLoad(LoadRequirementsEvent event, Emitter<RequirementsState> emit) async {
    emit(RequirementsLoading());
    _currentPage = 1;
    _hasMore = true;

    final result = await repository.getRequirements(page: 1, filters: event.filters);
    final myAcceptedResult = await repository.getAcceptedByMe();

    result.fold(
      (f) => emit(RequirementsError(message: f.message)),
      (data) {
        _hasMore = data['meta']?['hasNextPage'] ?? false;
        final myAccepted = myAcceptedResult.fold(
          (_) => <Map<String, dynamic>>[],
          (my) => List<Map<String, dynamic>>.from(my['data'] ?? []),
        );
        emit(RequirementsLoaded(
          requirements: List<Map<String, dynamic>>.from(data['data'] ?? []),
          myAccepted: myAccepted,
          isLoadingMore: false,
          hasMore: _hasMore,
        ));
      },
    );
  }

  Future<void> _onLoadMore(LoadMoreRequirementsEvent event, Emitter<RequirementsState> emit) async {
    final current = state;
    if (current is! RequirementsLoaded || !current.hasMore || current.isLoadingMore) return;

    emit(current.copyWith(isLoadingMore: true));
    _currentPage++;

    final result = await repository.getRequirements(page: _currentPage);
    result.fold(
      (f) => emit(current.copyWith(isLoadingMore: false)),
      (data) {
        final newItems = List<Map<String, dynamic>>.from(data['data'] ?? []);
        _hasMore = data['meta']?['hasNextPage'] ?? false;
        emit(RequirementsLoaded(
          requirements: [...current.requirements, ...newItems],
          isLoadingMore: false,
          hasMore: _hasMore,
        ));
      },
    );
  }

  Future<void> _onSearch(SearchRequirementsEvent event, Emitter<RequirementsState> emit) async {
    emit(RequirementsLoading());
    final result = await repository.getRequirements(search: event.query);
    result.fold(
      (f) => emit(RequirementsError(message: f.message)),
      (data) => emit(RequirementsLoaded(
        requirements: List<Map<String, dynamic>>.from(data['data'] ?? []),
        isLoadingMore: false,
        hasMore: false,
      )),
    );
  }

  Future<void> _onFilter(FilterRequirementsEvent event, Emitter<RequirementsState> emit) async {
    emit(RequirementsLoading());
    final result = await repository.getRequirements(filters: event.filters);
    result.fold(
      (f) => emit(RequirementsError(message: f.message)),
      (data) => emit(RequirementsLoaded(
        requirements: List<Map<String, dynamic>>.from(data['data'] ?? []),
        isLoadingMore: false,
        hasMore: data['meta']?['hasNextPage'] ?? false,
      )),
    );
  }

  Future<void> _onCreate(CreateRequirementEvent event, Emitter<RequirementsState> emit) async {
    final result = await repository.createRequirement(event.data);
    result.fold(
      (f) => emit(RequirementsError(message: f.message)),
      (data) {
        emit(RequirementCreated(requirement: data));
        add(const LoadRequirementsEvent());
      },
    );
  }

  Future<void> _onDelete(DeleteRequirementEvent event, Emitter<RequirementsState> emit) async {
    final result = await repository.deleteRequirement(event.id);
    result.fold(
      (f) => emit(RequirementsError(message: f.message)),
      (_) => add(const LoadRequirementsEvent()),
    );
  }

  Future<void> _onLoadDetail(LoadRequirementDetailEvent event, Emitter<RequirementsState> emit) async {
    emit(RequirementsLoading());
    final result = await repository.getRequirementById(event.id);
    result.fold(
      (f) => emit(RequirementsError(message: f.message)),
      (data) => emit(RequirementDetailLoaded(requirement: data['data'] as Map<String, dynamic>? ?? data)),
    );
  }

  Future<void> _onAccept(AcceptRequirementEvent event, Emitter<RequirementsState> emit) async {
    final result = await repository.acceptRequirement(event.id);
    result.fold(
      (f) => emit(RequirementsError(message: f.message)),
      (_) {
        emit(RequirementAccepted());
        add(LoadRequirementDetailEvent(event.id));
      },
    );
  }

  Future<void> _onUpdate(UpdateRequirementEvent event, Emitter<RequirementsState> emit) async {
    emit(RequirementsLoading());
    final result = await repository.updateRequirement(event.id, event.data);
    result.fold(
      (f) => emit(RequirementsError(message: f.message)),
      (data) => emit(RequirementUpdated(requirement: data['data'] as Map<String, dynamic>? ?? data)),
    );
  }

  Future<void> _onCancel(CancelRequirementEvent event, Emitter<RequirementsState> emit) async {
    emit(RequirementsLoading());
    final result = await repository.cancelRequirement(event.id, event.reason);
    result.fold(
      (f) => emit(RequirementsError(message: f.message)),
      (_) => emit(RequirementCancelled()),
    );
  }

  Future<void> _onLoadMy(LoadMyRequirementsEvent event, Emitter<RequirementsState> emit) async {
    emit(RequirementsLoading());
    final result = await repository.getMyRequirements();
    result.fold(
      (f) => emit(RequirementsError(message: f.message)),
      (data) => emit(MyRequirementsLoaded(
        requirements: List<Map<String, dynamic>>.from(data['data'] ?? []),
      )),
    );
  }
}