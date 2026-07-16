import 'package:flutter_laundry_offline_app/core/services/supabase_service.dart';
import 'package:flutter_laundry_offline_app/data/models/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

/// Repository for Supabase authentication
class SupabaseAuthRepository {
  final SupabaseService _supabase;

  SupabaseAuthRepository({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  SupabaseClient get _client => _supabase.client;

  /// Sign up a new user with email and password
  /// Creates outlet and profile automatically via database trigger
  Future<User> signUp({
    required String email,
    required String password,
    required String name,
    String? laundryName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'laundry_name': laundryName ?? 'My Laundry',
      },
    );

    if (response.user == null) {
      throw Exception('Failed to create account');
    }

    // Wait a moment for trigger to create profile
    await Future.delayed(const Duration(milliseconds: 500));

    // Get user profile
    return await getCurrentUser();
  }

  /// Sign in with email and password
  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('Invalid credentials');
    }

    return await getCurrentUser();
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get current authenticated user with profile
  Future<User> getCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw Exception('Not authenticated');
    }

    final profile = await _client
        .from('profiles')
        .select('*, outlets(*)')
        .eq('id', authUser.id)
        .single();

    return User(
      id: 0, // Local ID not used for Supabase users
      remoteId: authUser.id,
      username: authUser.email ?? '',
      name: profile['name'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == profile['role'],
        orElse: () => UserRole.kasir,
      ),
      isActive: profile['is_active'] ?? true,
      outletId: profile['outlet_id'],
      outletName: profile['outlets']?['name'],
      createdAt: DateTime.tryParse(profile['created_at'] ?? ''),
      updatedAt: DateTime.tryParse(profile['updated_at'] ?? ''),
    );
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Get current session
  Session? get currentSession => _client.auth.currentSession;

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Update password
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Update user profile
  Future<User> updateProfile({
    String? name,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Not authenticated');
    }

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;

    if (updates.isNotEmpty) {
      await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId);
    }

    return await getCurrentUser();
  }

  /// Get outlet info
  Future<Map<String, dynamic>?> getOutlet() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final profile = await _client
        .from('profiles')
        .select('outlet_id')
        .eq('id', userId)
        .single();

    if (profile['outlet_id'] == null) return null;

    final outlet = await _client
        .from('outlets')
        .select()
        .eq('id', profile['outlet_id'])
        .single();

    return outlet;
  }

  /// Update outlet info
  Future<void> updateOutlet({
    String? name,
    String? address,
    String? phone,
    String? invoicePrefix,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Not authenticated');
    }

    final profile = await _client
        .from('profiles')
        .select('outlet_id')
        .eq('id', userId)
        .single();

    if (profile['outlet_id'] == null) {
      throw Exception('No outlet found');
    }

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (address != null) updates['address'] = address;
    if (phone != null) updates['phone'] = phone;
    if (invoicePrefix != null) updates['invoice_prefix'] = invoicePrefix;

    if (updates.isNotEmpty) {
      await _client
          .from('outlets')
          .update(updates)
          .eq('id', profile['outlet_id']);
    }
  }

  /// Invite user to outlet (owner only)
  Future<void> inviteUser({
    required String email,
    required String name,
    required UserRole role,
  }) async {
    // This would typically send an invite email
    // For now, we'll create a pending invite record
    // The invited user would need to sign up and claim the invite
    throw UnimplementedError('Invite system not yet implemented');
  }
}
