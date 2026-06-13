part of 'subscription_bloc.dart';

abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();
  @override
  List<Object?> get props => [];
}

class LoadPlansEvent extends SubscriptionEvent {}
class LoadMySubscriptionEvent extends SubscriptionEvent {}

class CreateOrderEvent extends SubscriptionEvent {
  final String planId;
  const CreateOrderEvent(this.planId);
  @override
  List<Object?> get props => [planId];
}

class VerifyPaymentEvent extends SubscriptionEvent {
  final Map<String, dynamic> paymentData;
  const VerifyPaymentEvent(this.paymentData);
  @override
  List<Object?> get props => [paymentData];
}
