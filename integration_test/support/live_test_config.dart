const liveHostEmail = String.fromEnvironment('HOST_EMAIL');
const liveHostPassword = String.fromEnvironment('HOST_PASSWORD');

void assertLiveCredentialsConfigured() {
  if (liveHostEmail.isEmpty || liveHostPassword.isEmpty) {
    throw StateError(
      'HOST_EMAIL and HOST_PASSWORD dart defines are required for live Supabase integration tests.',
    );
  }
}
