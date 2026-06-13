import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_client.dart';

part 'subscription_event.dart';
part 'subscription_state.dart';

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final ApiClient apiClient;

  SubscriptionBloc(this.apiClient) : super(SubscriptionInitial()) {
    on<LoadPlansEvent>(_onLoadPlans);
    on<CreateOrderEvent>(_onCreateOrder);
    on<VerifyPaymentEvent>(_onVerify);
    on<LoadMySubscriptionEvent>(_onLoadMy);
  }

  Future<void> _onLoadPlans(LoadPlansEvent event, Emitter<SubscriptionState> emit) async {
    emit(SubscriptionLoading());
    try {
      final res = await apiClient.get('/subscriptions/plans');
      emit(PlansLoaded(plans: List<Map<String, dynamic>>.from(res.data['data'] ?? [])));
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
    }
  }

  Future<void> _onCreateOrder(CreateOrderEvent event, Emitter<SubscriptionState> emit) async {
    emit(SubscriptionLoading());
    try {
      final res = await apiClient.post('/subscriptions/create-order', data: {'planId': event.planId});
      emit(OrderCreated(orderData: res.data['data'] as Map<String, dynamic>));
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
    }
  }

  Future<void> _onVerify(VerifyPaymentEvent event, Emitter<SubscriptionState> emit) async {
    emit(SubscriptionLoading());
    try {
      await apiClient.post('/subscriptions/verify-payment', data: event.paymentData);
      emit(PaymentVerified());
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
    }
  }

  Future<void> _onLoadMy(LoadMySubscriptionEvent event, Emitter<SubscriptionState> emit) async {
    try {
      final res = await apiClient.get('/subscriptions/my');
      emit(MySubscriptionLoaded(subscription: res.data['data'] as Map<String, dynamic>?));
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
    }
  }
}
