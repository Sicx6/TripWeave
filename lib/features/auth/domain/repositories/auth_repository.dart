import '../entities/app_user.dart';

abstract interface class AuthRepository {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AppUser> login({required String email, required String password});
  Future<void> sendPasswordReset(String email);
  Future<void> logout();
  Future<AppUser> updateProfile({required String name, String? avatarPath});
}
