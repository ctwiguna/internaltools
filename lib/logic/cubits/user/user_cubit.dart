import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/models/user.dart';
import 'package:flutter_laundry_offline_app/data/repositories/user_repository.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/user/user_state.dart';

class UserCubit extends Cubit<UserState> {
  final UserRepository _userRepository;
  List<User> _users = [];

  final ConnectivityService _connectivity = ConnectivityService.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  UserCubit({UserRepository? userRepository})
      : _userRepository = userRepository ?? UserRepository(),
        super(const UserInitial());

  bool get _isOnline => _connectivity.isOnline && _supabase.isAuthenticated;

  List<User> get users => _users;

  /// Load all users
  Future<void> loadUsers() async {
    emit(const UserLoading());

    try {
      // Online: daftar user dari Supabase (sama di semua perangkat)
      if (_isOnline) {
        _users = await _userRepository.getAllUsersOnline();
      } else {
        _users = await _userRepository.getAllUsers();
      }
      emit(UserLoaded(_users));
    } catch (e) {
      emit(UserError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Create new user
  Future<void> createUser({
    required String username,
    required String password,
    required String name,
    required UserRole role,
    String? outletUuid,
  }) async {
    emit(const UserLoading());

    try {
      await _userRepository.createUser(
        username: username,
        password: password,
        name: name,
        role: role,
        outletUuid: outletUuid,
      );

      emit(const UserOperationSuccess('User berhasil ditambahkan'));

      // Reload users
      await loadUsers();
    } catch (e) {
      emit(UserError(e.toString().replaceAll('Exception: ', '')));
      // Re-emit loaded state to recover
      emit(UserLoaded(_users));
    }
  }

  /// Update user
  Future<void> updateUser({
    required int id,
    required String name,
    required UserRole role,
  }) async {
    emit(const UserLoading());

    try {
      await _userRepository.updateUser(
        id: id,
        name: name,
        role: role,
      );

      emit(const UserOperationSuccess('User berhasil diupdate'));

      // Reload users
      await loadUsers();
    } catch (e) {
      emit(UserError(e.toString().replaceAll('Exception: ', '')));
      // Re-emit loaded state to recover
      emit(UserLoaded(_users));
    }
  }

  /// Reset user password
  Future<void> resetPassword({
    required int userId,
    required String newPassword,
  }) async {
    emit(const UserLoading());

    try {
      await _userRepository.resetPassword(
        userId: userId,
        newPassword: newPassword,
      );

      emit(const UserOperationSuccess('Password berhasil direset'));

      // Re-emit loaded state
      emit(UserLoaded(_users));
    } catch (e) {
      emit(UserError(e.toString().replaceAll('Exception: ', '')));
      // Re-emit loaded state to recover
      emit(UserLoaded(_users));
    }
  }

  /// Toggle user active status
  Future<void> toggleUserStatus(int id) async {
    try {
      final isActive = await _userRepository.toggleUserStatus(id);
      final message = isActive ? 'User diaktifkan' : 'User dinonaktifkan';

      emit(UserOperationSuccess(message));

      // Reload users
      await loadUsers();
    } catch (e) {
      emit(UserError(e.toString().replaceAll('Exception: ', '')));
      // Re-emit loaded state to recover
      emit(UserLoaded(_users));
    }
  }
}
