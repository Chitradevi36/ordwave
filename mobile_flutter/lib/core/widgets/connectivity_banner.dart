import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/connectivity_service.dart';
import '../theme/colors.dart';

// ── Sync status enum ──────────────────────────────────────────────────────────

enum SyncBannerState { online, offline, syncing, synced }

final syncBannerStateProvider = StateProvider<SyncBannerState>((_) => SyncBannerState.online);

// ── ConnectivityBanner ────────────────────────────────────────────────────────

/// A banner that sits directly below the AppBar.  
/// Shows nothing when online+idle, and colored banners for:
/// • offline    → red "You're offline"
/// • syncing    → blue "Syncing..."
/// • synced     → green "All changes synced ✓" (auto-dismisses after 2s)
class ConnectivityBanner extends ConsumerStatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline  = ref.watch(isOnlineProvider);
    final syncState = ref.watch(syncBannerStateProvider);

    SyncBannerState effective;
    if (!isOnline) {
      effective = SyncBannerState.offline;
    } else {
      effective = syncState;
    }

    // Auto-dismiss "synced" after 2 seconds
    if (effective == SyncBannerState.synced) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          ref.read(syncBannerStateProvider.notifier).state = SyncBannerState.online;
        }
      });
    }

    final hide = effective == SyncBannerState.online;

    if (hide && _ctrl.value == 0) return const SizedBox.shrink();
    if (hide) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }

    Color   bgColor;
    IconData icon;
    String  label;
    Color   textColor = Colors.white;

    switch (effective) {
      case SyncBannerState.offline:
        bgColor = OlColors.error;
        icon    = Icons.wifi_off_rounded;
        label   = "You're offline — changes will sync when connected";
      case SyncBannerState.syncing:
        bgColor = const Color(0xFF1D4ED8); // blue-700
        icon    = Icons.sync;
        label   = 'Syncing your changes…';
      case SyncBannerState.synced:
        bgColor = OlColors.success;
        icon    = Icons.check_circle_outline;
        label   = 'All changes synced ✓';
      case SyncBannerState.online:
        bgColor = OlColors.success;
        icon    = Icons.check_circle_outline;
        label   = '';
    }

    return Semantics(
      liveRegion: true,
      label: hide ? null : label,
      child: SizeTransition(
        sizeFactor: _anim,
        child: Container(
          color: bgColor,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              effective == SyncBannerState.syncing
                  ? SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textColor,
                      ),
                    )
                  : Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
