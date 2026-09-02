import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(Supabase.instance.client);
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<void> build() async {}

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) =>
      _run(() => _repository.register(
            name: name,
            email: email,
            password: password,
          ));

  Future<bool> login({required String email, required String password}) =>
      _run(() => _repository.login(email: email, password: password));

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _repository.sendPasswordReset(email));

  Future<bool> logout() => _run(_repository.logout);

  Future<bool> updateProfile({required String name, String? avatarPath}) =>
      _run(() => _repository.updateProfile(name: name, avatarPath: avatarPath));

  Future<bool> _run(Future<Object?> Function() operation) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(operation);
    return !state.hasError;
  }
}
