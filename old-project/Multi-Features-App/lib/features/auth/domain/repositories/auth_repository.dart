import '../../../../core/models/user_model.dart';

/// Authentication repository interface
/// This will be implemented with actual API calls in the future
abstract class AuthRepository {
  Future<UserModel> login(String email, String password);
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
}


