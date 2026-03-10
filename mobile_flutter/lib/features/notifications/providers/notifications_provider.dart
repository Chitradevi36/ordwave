import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/app_database.dart';

// ── Simple row wrapper (avoids dependency on generated Drift data class name) ─
class LocalNotifRow {
  final int    id;
  final int?   serverId;
  final String type;
  final String title;
  final String body;
  final String? deepLink;
  final String severity;
  final bool   isRead;
  final String receivedAt;

  const LocalNotifRow({
    required this.id,
    this.serverId,
    required this.type,
    required this.title,
    required this.body,
    this.deepLink,
    required this.severity,
    required this.isRead,
    required this.receivedAt,
  });

  factory LocalNotifRow.fromRow(dynamic row) {
    return LocalNotifRow(
      id:          row.id          as int,
      serverId:    row.serverId    as int?,
      type:        row.type        as String,
      title:       row.title       as String,
      body:        row.body        as String,
      deepLink:    row.deepLink    as String?,
      severity:    row.severity    as String,
      isRead:      row.isRead      as bool,
      receivedAt:  row.receivedAt  as String,
    );
  }
}

// ── Service ────────────────────────────────────────────────────────────────────

class NotificationsService {
  const NotificationsService(this._db);
  final AppDatabase _db;

  Stream<List<LocalNotifRow>> watchAll() {
    return (_db.select(_db.localNotifications)
          ..orderBy([(n) => OrderingTerm.desc(n.receivedAt)]))
        .watch()
        .map((rows) => rows.map(LocalNotifRow.fromRow).toList());
  }

  Future<void> insert({
    required int?   serverId,
    required String type,
    required String title,
    required String body,
    String? deepLink,
    String  severity = 'medium',
  }) async {
    await _db.into(_db.localNotifications).insertOnConflictUpdate(
      LocalNotificationsCompanion(
        serverId:   Value(serverId),
        type:       Value(type),
        title:      Value(title),
        body:       Value(body),
        deepLink:   Value(deepLink),
        severity:   Value(severity),
        isRead:     const Value(false),
        receivedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<void> markRead(int id) async {
    await (_db.update(_db.localNotifications)
          ..where((n) => n.id.equals(id)))
        .write(const LocalNotificationsCompanion(isRead: Value(true)));
  }

  Future<void> markAllRead() async {
    await (_db.update(_db.localNotifications)
          ..where((n) => n.isRead.equals(false)))
        .write(const LocalNotificationsCompanion(isRead: Value(true)));
  }

  Future<int> countUnread() async {
    final count = _db.localNotifications.id.count();
    final q = _db.selectOnly(_db.localNotifications)
      ..addColumns([count])
      ..where(_db.localNotifications.isRead.equals(false));
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }
}

// ── Providers ──────────────────────────────────────────────────────────────────

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  return NotificationsService(ref.watch(appDatabaseProvider));
});

final notificationsStreamProvider = StreamProvider<List<LocalNotifRow>>((ref) {
  return ref.watch(notificationsServiceProvider).watchAll();
});

final unreadCountProvider = StreamProvider<int>((ref) {
  final svc = ref.watch(notificationsServiceProvider);
  return svc.watchAll().map((list) => list.where((n) => !n.isRead).length);
});
