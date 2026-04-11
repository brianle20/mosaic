import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CurrentUserReader = User? Function();
typedef AuthStateChangesReader = Stream<AuthState> Function();
typedef SignInWithPasswordAction = Future<AuthResponse> Function({
  required String email,
  required String password,
});
typedef SignOutAction = Future<void> Function();

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required CurrentUserReader currentUserReader,
    required AuthStateChangesReader authStateChangesReader,
    required SignInWithPasswordAction signInWithPasswordAction,
    required SignOutAction signOutAction,
  })  : _currentUserReader = currentUserReader,
        _authStateChangesReader = authStateChangesReader,
        _signInWithPasswordAction = signInWithPasswordAction,
        _signOutAction = signOutAction;

  factory SupabaseAuthRepository.fromClient(SupabaseClient client) {
    return SupabaseAuthRepository(
      currentUserReader: () => client.auth.currentUser,
      authStateChangesReader: () => client.auth.onAuthStateChange,
      signInWithPasswordAction: ({
        required String email,
        required String password,
      }) {
        return client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      },
      signOutAction: client.auth.signOut,
    );
  }

  final CurrentUserReader _currentUserReader;
  final AuthStateChangesReader _authStateChangesReader;
  final SignInWithPasswordAction _signInWithPasswordAction;
  final SignOutAction _signOutAction;

  @override
  HostAuthUser? get currentHost => _mapUser(_currentUserReader());

  @override
  Stream<HostAuthUser?> authStateChanges() {
    return _authStateChangesReader().map((_) => currentHost);
  }

  @override
  Future<HostAuthUser?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _signInWithPasswordAction(
      email: email,
      password: password,
    );
    return _mapUser(response.user);
  }

  @override
  Future<void> signOut() {
    return _signOutAction();
  }

  HostAuthUser? _mapUser(User? user) {
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      return null;
    }

    return HostAuthUser(
      id: user.id,
      email: email,
    );
  }
}
