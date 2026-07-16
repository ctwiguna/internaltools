import 'package:equatable/equatable.dart';
import 'package:flutter_laundry_offline_app/data/models/outlet.dart';

abstract class OutletState extends Equatable {
  const OutletState();

  @override
  List<Object?> get props => [];
}

class OutletInitial extends OutletState {}

class OutletLoading extends OutletState {}

class OutletLoaded extends OutletState {
  final List<Outlet> outlets;
  final Outlet? currentOutlet;

  const OutletLoaded({
    required this.outlets,
    this.currentOutlet,
  });

  @override
  List<Object?> get props => [outlets, currentOutlet];
}

class OutletSwitching extends OutletState {}

class OutletSwitched extends OutletState {
  final Outlet outlet;
  final String message;

  const OutletSwitched({
    required this.outlet,
    required this.message,
  });

  @override
  List<Object?> get props => [outlet, message];
}

class OutletCreating extends OutletState {}

class OutletCreated extends OutletState {
  final Outlet outlet;
  final String message;

  const OutletCreated({
    required this.outlet,
    required this.message,
  });

  @override
  List<Object?> get props => [outlet, message];
}

class OutletUpdating extends OutletState {}

class OutletUpdated extends OutletState {
  final Outlet outlet;
  final String message;

  const OutletUpdated({
    required this.outlet,
    required this.message,
  });

  @override
  List<Object?> get props => [outlet, message];
}

class OutletError extends OutletState {
  final String message;

  const OutletError({required this.message});

  @override
  List<Object?> get props => [message];
}
