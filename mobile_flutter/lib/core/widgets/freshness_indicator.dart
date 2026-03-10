import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Shows how stale cached data is.
/// • < 1 min  → nothing / "Just now"
/// • 1–59 min → "Updated X min ago"  (neutral)
/// • 1–24 h   → "Updated X hours ago" (amber warning)
/// • > 24 h   → "Last synced {date}" (red + optional Sync CTA)
class FreshnessIndicator extends StatelessWidget {
  const FreshnessIndicator({
    super.key,
    required this.lastSyncedAt,
    this.onSyncNow,
    this.compact = false,
  });

  final DateTime?    lastSyncedAt;
  final VoidCallback? onSyncNow;
  /// When true shows only an icon + short text (for AppBar/tile use).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (lastSyncedAt == null) return const SizedBox.shrink();

    final diff  = DateTime.now().difference(lastSyncedAt!);
    final label = _freshnessLabel(diff);
    final level = _freshnessLevel(diff);

    final Color textColor;
    final IconData icon;

    switch (level) {
      case _Level.fresh:
        textColor = OlColors.textSecondary;
        icon      = Icons.check_circle_outline;
      case _Level.ok:
        textColor = OlColors.textSecondary;
        icon      = Icons.access_time_outlined;
      case _Level.warn:
        textColor = OlColors.warning;
        icon      = Icons.schedule_outlined;
      case _Level.stale:
        textColor = OlColors.error;
        icon      = Icons.warning_amber_outlined;
    }

    if (compact) {
      return Tooltip(
        message: label,
        child: Icon(icon, size: 14, color: textColor,
            semanticLabel: 'Data freshness: $label'),
      );
    }

    return GestureDetector(
      onTap: (level == _Level.stale || level == _Level.warn) ? onSyncNow : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500),
          ),
          if ((level == _Level.stale || level == _Level.warn) && onSyncNow != null) ...[
            const SizedBox(width: 6),
            Text(
              '· Sync Now',
              style: TextStyle(
                fontSize: 11,
                color: textColor,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _freshnessLabel(Duration diff) {
    if (diff.inSeconds < 60)  return 'Updated just now';
    if (diff.inMinutes < 60)  return 'Updated ${diff.inMinutes} min ago';
    if (diff.inHours < 24)    return 'Updated ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays == 1)     return 'Last synced yesterday';
    return 'Last synced ${diff.inDays} days ago';
  }

  static _Level _freshnessLevel(Duration diff) {
    if (diff.inMinutes < 5)  return _Level.fresh;
    if (diff.inHours  < 1)   return _Level.ok;
    if (diff.inHours  < 24)  return _Level.warn;
    return _Level.stale;
  }
}

enum _Level { fresh, ok, warn, stale }
