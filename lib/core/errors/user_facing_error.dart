/// Converts repository failures into copy that is safe to show to a host.
///
/// Backend protocol details and identifiers are intentionally omitted from
/// normal event UI. Human-readable state errors are retained when they do not
/// contain technical diagnostics.
String userFacingError(
  Object error, {
  String fallback = 'Unable to complete that request right now.',
}) {
  var message = error.toString().trim();
  if (message.startsWith('Bad state: ')) {
    message = message.substring('Bad state: '.length).trim();
  }
  final technical = message.contains('PostgrestException') ||
      message.contains('Postgrest') ||
      message.contains('RPC') ||
      message.contains('rpc') ||
      message.contains('Supabase') ||
      message.contains('SQL') ||
      message.contains('23505') ||
      RegExp(r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b')
          .hasMatch(message);
  if (message.isEmpty || technical) {
    return fallback;
  }
  return message;
}
