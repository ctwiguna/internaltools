import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_laundry_offline_app/core/services/connectivity_service.dart';
import 'package:flutter_laundry_offline_app/core/services/outlet_service.dart';
import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/database/database_helper.dart';
import 'package:flutter_laundry_offline_app/data/models/user.dart';
import 'package:flutter_laundry_offline_app/data/repositories/auth_repository.dart';
import 'package:flutter_laundry_offline_app/data/repositories/supabase_auth_repository.dart';
import 'package:flutter_laundry_offline_app/logic/cubits/auth/auth_state.dart';

enum AuthMode { offline, online }

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _offlineAuthRepository;
  final SupabaseAuthRepository _onlineAuthRepository;
  final ConnectivityService _connectivity;
  User? _currentUser;
  AuthMode _authMode = AuthMode.offline;

  AuthCubit({
    AuthRepository? offlineAuthRepository,
    SupabaseAuthRepository? onlineAuthRepository,
    ConnectivityService? connectivity,
  })  : _offlineAuthRepository = offlineAuthRepository ?? AuthRepository(),
        _onlineAuthRepository = onlineAuthRepository ?? SupabaseAuthRepository(),
        _connectivity = connectivity ?? ConnectivityService.instance,
        super(const AuthInitial());

  /// Get current user
  User? get currentUser => _currentUser;

  /// Get current auth mode
  AuthMode get authMode => _authMode;

  /// Check if using online auth
  bool get isOnlineMode => _authMode == AuthMode.online;

  /// Check auth status on app start
  Future<void> checkAuthStatus() async {
    emit(const AuthLoading());

    try {
      // First, check if there's an online session
      if (_onlineAuthRepository.isAuthenticated) {
        try {
          // Add timeout to prevent hanging on slow network
          final user = await _onlineAuthRepository.getCurrentUser()
              .timeout(const Duration(seconds: 5));
          _currentUser = user;
          _authMode = AuthMode.online;
          emit(AuthAuthenticated(user));
          return;
        } catch (_) {
          // Online auth failed (timeout or error), try offline
        }
      }

      // Fall back to offline auth
      final user = await _offlineAuthRepository.getCurrentUser();

      if (user != null) {
        _currentUser = user;
        _authMode = AuthMode.offline;
        emit(AuthAuthenticated(user));
      } else {
        _currentUser = null;
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      _currentUser = null;
      emit(const AuthUnauthenticated());
    }
  }

  /// Login with username/email and password
  /// Tries online first if connected, then falls back to offline
  Future<void> login(String usernameOrEmail, String password) async {
    emit(const AuthLoading());

    try {
      if (usernameOrEmail.trim().isEmpty) {
        emit(const AuthError('Username/Email tidak boleh kosong'));
        return;
      }

      if (password.isEmpty) {
        emit(const AuthError('Password tidak boleh kosong'));
        return;
      }

      // Username polos di-map ke email internal Supabase
      // (mis. 'ctwiguna' -> 'ctwiguna@zennlaundry.internal')
      final email = usernameOrEmail.contains('@')
          ? usernameOrEmail.trim()
          : '${usernameOrEmail.trim().toLowerCase()}@zennlaundry.internal';

      // Coba login online (Supabase) dulu jika ada koneksi
      if (_connectivity.isOnline) {
        try {
          final user = await _onlineAuthRepository.signIn(
            email: email,
            password: password,
          );
          _currentUser = user;
          _authMode = AuthMode.online;

          // Sync outlet from Supabase to local
          await _syncOutletFromSupabase();

          emit(AuthAuthenticated(user));
          return;
        } catch (_) {
          // Gagal online (password salah / akun belum ada / jaringan)
          // -> lanjut coba login offline di bawah (masa transisi)
        }
      }

      // Offline auth (username-based)
      final user = await _offlineAuthRepository.login(usernameOrEmail, password);
      _currentUser = user;
      _authMode = AuthMode.offline;
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Register new account (online only)
  Future<void> register({
    required String email,
    required String password,
    required String name,
    String? laundryName,
  }) async {
    emit(const AuthLoading());

    try {
      if (!_connectivity.isOnline) {
        emit(const AuthError('Registrasi membutuhkan koneksi internet'));
        return;
      }

      if (email.trim().isEmpty || !email.contains('@')) {
        emit(const AuthError('Email tidak valid'));
        return;
      }

      if (password.length < 6) {
        emit(const AuthError('Password minimal 6 karakter'));
        return;
      }

      if (name.trim().isEmpty) {
        emit(const AuthError('Nama tidak boleh kosong'));
        return;
      }

      final user = await _onlineAuthRepository.signUp(
        email: email,
        password: password,
        name: name,
        laundryName: laundryName,
      );

      _currentUser = user;
      _authMode = AuthMode.online;
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Logout
  Future<void> logout() async {
    emit(const AuthLoading());

    try {
      if (_authMode == AuthMode.online) {
        await _onlineAuthRepository.signOut();
      } else {
        await _offlineAuthRepository.logout();
      }
      _currentUser = null;
      _authMode = AuthMode.offline;
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (_currentUser == null) {
      emit(const AuthError('User tidak ditemukan'));
      return;
    }

    if (newPassword != confirmPassword) {
      emit(const AuthError('Konfirmasi password tidak cocok'));
      return;
    }

    if (newPassword.length < 6) {
      emit(const AuthError('Password minimal 6 karakter'));
      return;
    }

    emit(const AuthLoading());

    try {
      if (_authMode == AuthMode.online) {
        await _onlineAuthRepository.updatePassword(newPassword);
      } else {
        await _offlineAuthRepository.changePassword(
          userId: _currentUser!.id!,
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      }

      emit(const AuthPasswordChanged());
      // Re-emit authenticated state
      emit(AuthAuthenticated(_currentUser!));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
      // Re-emit authenticated state to recover
      emit(AuthAuthenticated(_currentUser!));
    }
  }

  /// Send password reset email (online only)
  Future<void> resetPassword(String email) async {
    emit(const AuthLoading());

    try {
      if (!_connectivity.isOnline) {
        emit(const AuthError('Reset password membutuhkan koneksi internet'));
        return;
      }

      await _onlineAuthRepository.resetPassword(email);
      emit(const AuthPasswordResetSent());
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Refresh current user data
  Future<void> refreshUser() async {
    try {
      User? user;
      if (_authMode == AuthMode.online) {
        user = await _onlineAuthRepository.getCurrentUser();
      } else {
        user = await _offlineAuthRepository.getCurrentUser();
      }
      if (user != null) {
        _currentUser = user;
        emit(AuthAuthenticated(user));
      }
    } catch (_) {}
  }

  /// Sync outlet from Supabase profile to local outlet
  Future<void> _syncOutletFromSupabase() async {
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) return;

      // Get profile with outlet info
      final profile = await SupabaseService.instance.client
          .from('profiles')
          .select('outlet_id, outlets(id, name, address, phone, invoice_prefix)')
          .eq('id', userId)
          .single();

      final remoteOutletId = profile['outlet_id'] as String?;
      if (remoteOutletId == null) return;

      final outletData = profile['outlets'] as Map<String, dynamic>?;
      if (outletData == null) return;

      final db = await DatabaseHelper.instance.database;

      // Check if we already have this outlet linked locally
      final existing = await db.query(
        'outlets',
        where: 'remote_id = ?',
        whereArgs: [remoteOutletId],
      );

      int localOutletId;

      if (existing.isNotEmpty) {
        // Update existing outlet
        localOutletId = existing.first['id'] as int;
        await db.update(
          'outlets',
          {
            'name': outletData['name'],
            'address': outletData['address'],
            'phone': outletData['phone'],
            'invoice_prefix': outletData['invoice_prefix'] ?? 'INV',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [localOutletId],
        );
      } else {
        // Check if we have a default outlet that's not linked yet
        final defaultOutlet = await db.query(
          'outlets',
          where: 'remote_id IS NULL',
          limit: 1,
        );

        if (defaultOutlet.isNotEmpty) {
          // Link the default outlet to remote
          localOutletId = defaultOutlet.first['id'] as int;
          await db.update(
            'outlets',
            {
              'remote_id': remoteOutletId,
              'name': outletData['name'],
              'address': outletData['address'],
              'phone': outletData['phone'],
              'invoice_prefix': outletData['invoice_prefix'] ?? 'INV',
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [localOutletId],
          );
        } else {
          // Create new outlet
          localOutletId = await db.insert('outlets', {
            'remote_id': remoteOutletId,
            'name': outletData['name'],
            'address': outletData['address'],
            'phone': outletData['phone'],
            'invoice_prefix': outletData['invoice_prefix'] ?? 'INV',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // Set as current outlet
      await OutletService.instance.setCurrentOutlet(localOutletId);
      debugPrint('Outlet synced from Supabase: $localOutletId ($remoteOutletId)');
    } catch (e) {
      debugPrint('Failed to sync outlet from Supabase: $e');
    }
  }
}
