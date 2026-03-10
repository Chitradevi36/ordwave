import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/notifications_provider.dart';

class NotificationInboxScreen extends ConsumerWidget {
  const NotificationInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationsServiceProvider).markAllRead(),
            child: const Text('Mark all read', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      body: notifsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifs) {
          if (notifs.isEmpty) return AppEmptyState.allCaughtUp();

          final unread = notifs.where((n) => !n.isRead).toList();
          final read   = notifs.where((n) => n.isRead).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (unread.isNotEmpty) ...[
                _SectionHeader(title: 'New', count: unread.length),
                ...unread.map((n) => _NotifTile(notif: n, ref: ref)),
              ],
              if (read.isNotEmpty) ...[
                _SectionHeader(title: 'Earlier', count: null),
                ...read.map((n) => _NotifTile(notif: n, ref: ref)),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Tile ───────────────────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.notif, required this.ref});
  final LocalNotifRow notif;
  final WidgetRef     ref;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notif.isRead;
    final color    = _severityColor(notif.severity);

    return InkWell(
      onTap: () {
        ref.read(notificationsServiceProvider).markRead(notif.id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUnread ? color.withOpacity(0.05) : AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dot / icon
            Container(
              margin: const EdgeInsets.only(top: 4, right: 10),
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: isUnread ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: isUnread ? null : Border.all(color: AppColors.border),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif.body,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notif.receivedAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Severity badge
            if (notif.severity == 'high')
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Urgent', style: TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'high':   return AppColors.danger;
      case 'medium': return AppColors.warning;
      default:       return AppColors.accent;
    }
  }

  String _timeAgo(String isoStr) {
    try {
      final dt   = DateTime.parse(isoStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return isoStr.length >= 10 ? isoStr.substring(0, 10) : isoStr;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count});
  final String title;
  final int?   count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.8)),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
              child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}

