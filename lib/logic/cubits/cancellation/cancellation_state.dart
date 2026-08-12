import 'package:equatable/equatable.dart';
import 'package:flutter_laundry_offline_app/data/models/cancellation_request.dart';

abstract class CancellationState extends Equatable {
  const CancellationState();

  @override
  List<Object?> get props => [];
}

class CancellationInitial extends CancellationState {
  const CancellationInitial();
}

class CancellationLoading extends CancellationState {
  const CancellationLoading();
}

class CancellationLoaded extends CancellationState {
  final List<CancellationRequest> requests;
  final CancellationStatus? filterStatus;

  const CancellationLoaded(this.requests, {this.filterStatus});

  @override
  List<Object?> get props => [requests, filterStatus];
}

class CancellationRequestSuccess extends CancellationState {
  final String message;

  const CancellationRequestSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class CancellationReviewSuccess extends CancellationState {
  final String message;

  const CancellationReviewSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class CancellationError extends CancellationState {
  final String message;

  const CancellationError(this.message);

  @override
  List<Object?> get props => [message];
}
