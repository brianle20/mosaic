import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase/supabase.dart';

typedef CurrentUserReader = User? Function();
typedef AuthStateChangesReader = Stream<AuthState> Function();
typedef SignInWithPasswordAction = Future<AuthResponse> Function({
  required String email,
  required String password,
});
typedef SendEmailOtpAction = Future<void> Function({
  required String email,
  required bool shouldCreateUser,
});
typedef VerifyEmailOtpAction = Future<AuthResponse> Function({
  required String email,
  required String token,
  required OtpType type,
});
typedef LoadCurrentAccessAction = Future<Object?> Function();
typedef SignOutAction = Future<void> Function();

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required CurrentUserReader currentUserReader,
    required AuthStateChangesReader authStateChangesReader,
    required SignInWithPasswordAction signInWithPasswordAction,
    required SendEmailOtpAction sendEmailOtpAction,
    required VerifyEmailOtpAction verifyEmailOtpAction,
    required LoadCurrentAccessAction loadCurrentAccessAction,
    required SignOutAction signOutAction,
  })  : _currentUserReader = currentUserReader,
        _authStateChangesReader = authStateChangesReader,
        _signInWithPasswordAction = signInWithPasswordAction,
        _sendEmailOtpAction = sendEmailOtpAction,
        _verifyEmailOtpAction = verifyEmailOtpAction,
        _loadCurrentAccessAction = loadCurrentAccessAction,
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
      sendEmailOtpAction: ({
        required String email,
        required bool shouldCreateUser,
      }) {
        return client.auth.signInWithOtp(
          email: email,
          shouldCreateUser: shouldCreateUser,
        );
      },
      verifyEmailOtpAction: ({
        required String email,
        required String token,
        required OtpType type,
      }) {
        return client.auth.verifyOTP(
          email: email,
          token: token,
          type: type,
        );
      },
      loadCurrentAccessAction: () async {
        return client.rpc('get_current_mosaic_access');
      },
      signOutAction: client.auth.signOut,
    );
  }

  final CurrentUserReader _currentUserReader;
  final AuthStateChangesReader _authStateChangesReader;
  final SignInWithPasswordAction _signInWithPasswordAction;
  final SendEmailOtpAction _sendEmailOtpAction;
  final VerifyEmailOtpAction _verifyEmailOtpAction;
  final LoadCurrentAccessAction _loadCurrentAccessAction;
  final SignOutAction _signOutAction;

  @override
  HostAuthUser? get currentHost => _mapUser(_currentUserReader());

  @override
  Stream<HostAuthUser?> authStateChanges() {
    return _authStateChangesReader().map((_) => currentHost);
  }

  @override
  Future<MosaicAccessState> loadCurrentAccess() async {
    return MosaicAccessState.fromRpcResponse(
      await _loadCurrentAccessAction(),
      userId: _currentUserReader()?.id,
    );
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
  Future<void> sendEmailOtp({required String email}) {
    return _sendEmailOtpAction(email: email, shouldCreateUser: true);
  }

  @override
  Future<HostAuthUser?> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    final response = await _verifyEmailOtpAction(
      email: email,
      token: code,
      type: OtpType.email,
    );
    return _mapUser(response.user);
  }

  @override
  Future<void> signOut() {
    return _signOutAction();
  }

  HostAuthUser? _mapUser(User? user) {
    final email = user?.email;
    final phone = user?.phone;
    if (user == null ||
        ((email == null || email.isEmpty) &&
            (phone == null || phone.isEmpty))) {
      return null;
    }

    return HostAuthUser(
      id: user.id,
      email: email,
      phoneE164: phone,
    );
  }
}
