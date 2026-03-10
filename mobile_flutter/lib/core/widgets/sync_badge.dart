import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Sync status for a single local entity (pending order, payment, etc.)
enum SyncStatus { pending, syncing, synced, failed }

/// A small badge/chip that communicates the sync state of an individual record.
class SyncBadge extends StatefulWidget {
  const SyncBadge({
    super.key,
    required this.status,
    this.compact = false,
    this.onTap,
  });

  final SyncStatus status;
  /// When true, show only an icon (no label text). Good for list tiles.
  final bool compact;
  final VoidCallback? onTap;

  @override
  State<SyncBadge> createState() => _SyncBadgeState();
}

class _SyncBadgeState extends State<SyncBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon, String label, String tooltip) =
        _config(widget.status);

    if (widget.compact) {
      final iconWidget = widget.status == SyncStatus.syncing
          ? RotationTransition(
              turns: _spin,
              child: Icon(Icons.sync, size: 14, color: fg, semanticLabel: tooltip),
            )
          : Icon(icon, size: 14, color: fg, semanticLabel: tooltip);

      return Tooltip(message: tooltip, child: iconWidget);
    }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.status == SyncStatus.syncing
                  ? RotationTransition(
                      turns: _spin,
                      child: Icon(Icons.sync, size: 10, color: fg),
                    )
                  : Icon(icon, size: 10, color: fg),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  static (Color, Color, IconData, String, String) _config(SyncStatus s) {
    return switch (s) {
      SyncStatus.pending => (
          OlColors.warning50,
          OlColors.warning,
          Icons.schedule_outlined,
          'Pending sync',
          'This record is waiting to sync',
        ),
      SyncStatus.syncing => (
          const Color(0xFFEFF6FF),
          const Color(0xFF1D4ED8),
          Icons.sync,
          'Syncing…',
          'Uploading to server',
        ),
      SyncStatus.synced => (
          OlColors.success50,
          OlColors.success,
          Icons.check_circle_outline,
          'Synced',
          'Saved to server',
        ),
      SyncStatus.failed => (
          OlColors.error50,
          OlColors.error,
          Icons.warning_amber_rounded,
          'Sync failed',
          'Tap to retry',
        ),
    };
  }
}
