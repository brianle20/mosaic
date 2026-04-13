import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class TableListController extends ChangeNotifier {
  TableListController({
    required TableRepository tableRepository,
    required SessionRepository sessionRepository,
  })  : _tableRepository = tableRepository,
        _sessionRepository = sessionRepository;

  final TableRepository _tableRepository;
  final SessionRepository _sessionRepository;

  bool isLoading = true;
  String? error;
  List<EventTableRecord> tables = const [];
  Map<String, TableSessionRecord> activeSessionsByTableId = const {};

  Future<void> load(String eventId) async {
    final cachedTables = await _tableRepository.readCachedTables(eventId);
    final cachedSessions = await _sessionRepository.readCachedSessions(eventId);

    isLoading = true;
    error = null;
    tables = cachedTables;
    activeSessionsByTableId = _activeSessionsByTable(cachedSessions);
    notifyListeners();

    try {
      tables = await _tableRepository.listTables(eventId);
    } catch (exception) {
      if (tables.isEmpty && activeSessionsByTableId.isEmpty) {
        error = exception.toString();
      }
    }

    try {
      final sessions = await _sessionRepository.listSessions(eventId);
      activeSessionsByTableId = _activeSessionsByTable(sessions);
    } catch (exception) {
      if (tables.isEmpty && activeSessionsByTableId.isEmpty) {
        error ??= exception.toString();
      }
    }

    isLoading = false;
    notifyListeners();
  }

  Map<String, TableSessionRecord> _activeSessionsByTable(
    List<TableSessionRecord> sessions,
  ) {
    return {
      for (final session in sessions)
        if (session.status == SessionStatus.active ||
            session.status == SessionStatus.paused)
          session.eventTableId: session,
    };
  }
}
