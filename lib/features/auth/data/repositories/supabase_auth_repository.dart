import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  AppUser? get currentUser {
    final user = _client.auth.currentUser;
    return user == null ? null : _mapUser(user);
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield currentUser;
    await for (final state in _client.auth.onAuthStateChange) {
      yield state.session?.user == null ? null : _mapUser(state.session!.user);
    }
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': name.trim()},
    );
    final user = result.user;
    if (user == null) throw const AuthException('Registration failed.');
    return _mapUser(user);
  }

  @override
  Future<AppUser> login(
      {required String email, required String password}) async {
    final result = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return _mapUser(result.user!);
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email.trim());

  @override
  Future<void> logout() => _client.auth.signOut();

  @override
  Future<AppUser> updateProfile(
      {required String name, String? avatarPath}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('You are not signed in.');

    String? avatarUrl = user.userMetadata?['avatar_url'] as String?;
    if (avatarPath != null) {
      final extension = avatarPath.split('.').last.toLowerCase();
      final storagePath = '${user.id}/avatar.$extension';
      await _client.storage.from('avatars').upload(
            storagePath,
            File(avatarPath),
            fileOptions: const FileOptions(upsert: true),
          );
      avatarUrl = _client.storage.from('avatars').getPublicUrl(storagePath);
    }

    final response = await _client.auth.updateUser(
      UserAttributes(
          data: {'display_name': name.trim(), 'avatar_url': avatarUrl}),
    );
    await _client.from('profiles').upsert({
      'id': user.id,
      'display_name': name.trim(),
      'avatar_url': avatarUrl,
    });
    return _mapUser(response.user!);
  }

  AppUser _mapUser(User user) => AppUser(
        id: user.id,
        email: user.email ?? '',
        displayName: (user.userMetadata?['display_name'] as String?)
                    ?.trim()
                    .isNotEmpty ==
                true
            ? user.userMetadata!['display_name'] as String
            : user.email?.split('@').first ?? 'Traveller',
        avatarUrl: user.userMetadata?['avatar_url'] as String?,
      );
}
