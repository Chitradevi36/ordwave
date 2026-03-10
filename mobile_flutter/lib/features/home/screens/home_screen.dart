import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/crash_recovery_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../retailers/repository/retailer_repository.dart';
import '../../products/repository/product_repository.dart';
import '../../collections/providers/collection_provider.dart';

// ── Simple user model ─────────────────────────────────────────────────────────
class UserProfile {
  final int    id;
  final String name;
  final String email;
  final String role;
  final String? branchName;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.branchName,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id:         (json['id'] as num).toInt(),
        name:       json['name']?.toString() ?? json['full_name']?.toString() ?? '',
        email:      json['email']?.toString() ?? '',
        role:       json['role']?.toString() ?? 'unknown',
        branchName: json['branch_name']?.toString(),
      );

  String get firstName {
    final parts = name.split(' ');
    return parts.isNotEmpty ? parts.first : name;
  }
}

// ── Sales Rep Home ─────────────────────────────────────────────────────────────
class SalesRepHome extends ConsumerStatefulWidget {
  const SalesRepHome({super.key});

  @override
  ConsumerState<SalesRepHome> createState() => _SalesRepHomeState();
}

class _SalesRepHomeState extends ConsumerState<SalesRepHome> {
  UserProfile? _user;
  bool _syncing = false;
  String? _syncStatus;

  @override
  void initState() {
    super.initState();
    _loadUser();
    // Kick off background sync after first frame so providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIfNeeded());
  }

  Future<void> _loadUser() async {
    final storage = ref.read(secureStorageProvider);
    final userJson = await storage.getUserJson();
    if (userJson == null || !mounted) return;
    try {
      setState(() {
        _user = UserProfile.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      });
    } catch (_) {}
  }

  Future<void> _syncIfNeeded() async {
    final retailerRepo = ref.read(retailerRepositoryProvider);
    final productRepo  = ref.read(productRepositoryProvider);
    final needsR = await retailerRepo.needsSync();
    final needsP = await productRepo.needsSync();
    if (!needsR && !needsP) return;
    if (!mounted) return;
    setState(() { _syncing = true; _syncStatus = 'Syncing data…'; });
    try {
      if (needsR) await ref.read(retailerSyncProvider.notifier).sync();
      if (needsP) await ref.read(productSyncProvider.notifier).sync();
      if (mounted) setState(() { _syncStatus = 'Synced'; });
      await Future<void>.delayed(const Duration(seconds: 2));
    } finally {
      if (mounted) setState(() { _syncing = false; _syncStatus = null; });
    }
  }

  Future<void> _manualSync() async {
    if (_syncing) return;
    setState(() { _syncing = true; _syncStatus = 'Syncing…'; });
    try {
      await ref.read(retailerSyncProvider.notifier).sync();
      await ref.read(productSyncProvider.notifier).sync();
      if (mounted) setState(() { _syncStatus = 'Done'; });
      await Future<void>.delayed(const Duration(seconds: 2));
    } finally {
      if (mounted) setState(() { _syncing = false; _syncStatus = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('OrderLane Pro'),
        actions: [
          // Sync indicator
          if (_syncing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Tooltip(
                message: _syncStatus ?? 'Syncing…',
                child: const SizedBox(
                  height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _manualSync,
              tooltip: 'Sync now',
              icon: const Icon(Icons.sync),
            ),
          IconButton(
            onPressed: () => context.go('/home/settings'),
            icon: const CircleAvatar(
              backgroundColor: OlColors.primary,
              radius: 14,
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { await _loadUser(); await _manualSync(); },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Crash recovery prompt ─────────────────────────────────
            CrashRecoveryBanner(
              onResume: (intent) {
                if (intent.type == RecoveryType.resumeOrder) {
                  context.push('/home/orders/new');
                } else if (intent.type == RecoveryType.resumeDelivery) {
                  context.push('/home/delivery');
                }
              },
            ),

            // ── Greeting ─────────────────────────────────────────────
            Text(
              _user != null
                  ? '${_getGreeting(now)}, ${_user!.firstName} 👋'
                  : _getGreeting(now),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: OlColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormatter.date(now),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: OlColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // ── KPI row ───────────────────────────────────────────────
            Row(
              children: [
                _KpiCard(label: 'Visits Today', value: '0 / 8', icon: Icons.map_outlined, color: OlColors.info),
                const SizedBox(width: 8),
                _KpiCard(label: 'Orders', value: '₹0', icon: Icons.shopping_cart_outlined, color: OlColors.success),
                const SizedBox(width: 8),
                _KpiCard(label: 'Collections', value: '₹0', icon: Icons.payments_outlined, color: OlColors.primary),
              ],
            ),
            const SizedBox(height: 24),

            // ── Today's Beat ──────────────────────────────────────────
            Row(
              children: [
                Text(
                  "Today's Beat",
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go(AppRoutes.beatPlan),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _EmptyState(
              icon: Icons.route_outlined,
              title: 'No beat assigned today',
              body: 'Your manager will assign your beat plan shortly.',
            ),

            const SizedBox(height: 24),

            // ── Recent Orders ─────────────────────────────────────────
            Text(
              'Recent Orders',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet today',
              body: 'Tap + to create your first order.',
            ),

            const SizedBox(height: 24),

            // ── Today's Collections ────────────────────────────────────
            Row(
              children: [
                Text(
                  "Today's Collections",
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/home/collections'),
                  child: const Text('View Schedule'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TodayCollectionsList(),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/home/collections/recent'),
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('Recent Collections', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OlColors.textPrimary,
                      side: const BorderSide(color: OlColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/home/collect'),
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text('Quick Collect', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OlColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/home/orders/new'),
        backgroundColor: OlColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Order', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  String _getGreeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ── Today's Collections Mini-List (home screen widget) ────────────────────────
class _TodayCollectionsList extends ConsumerStatefulWidget {
  const _TodayCollectionsList();

  @override
  ConsumerState<_TodayCollectionsList> createState() =>
      _TodayCollectionsListState();
}

class _TodayCollectionsListState extends ConsumerState<_TodayCollectionsList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      ref.read(collectionSchedulesProvider.notifier).fetch(date: today);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state     = ref.watch(collectionSchedulesProvider);
    final planned   = state.schedules.where((s) => s.status == 'planned').take(3).toList();
    final theme     = Theme.of(context);

    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SizedBox(height: 24, width: 24,
            child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (planned.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: OlColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OlColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: OlColors.success, size: 20),
            const SizedBox(width: 10),
            Text(
              'No pending collections today',
              style: theme.textTheme.bodySmall?.copyWith(color: OlColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: planned.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.go('/home/collect', extra: {
              'customerId':           s.customerId,
              'customerName':         s.customerName,
              'amount':               s.amountExpected,
              'collectionScheduleId': s.id,
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:        OlColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: s.isOverdue ? OlColors.error.withOpacity(0.5) : OlColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.store_outlined,
                    size: 16,
                    color: s.isOverdue ? OlColors.error : OlColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.customerName ?? 'Customer',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          s.isOverdue ? 'Overdue' : s.scheduledDate,
                          style: TextStyle(
                            fontSize: 11,
                            color: s.isOverdue ? OlColors.error : OlColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(s.amountExpected),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: OlColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, size: 16, color: OlColors.textSecondary),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Driver Home ────────────────────────────────────────────────────────────────
class DriverHome extends ConsumerStatefulWidget {
  const DriverHome({super.key});

  @override
  ConsumerState<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends ConsumerState<DriverHome> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('OrderLane Pro'),
        actions: [
          IconButton(
            onPressed: () => context.go('/home/settings'),
            icon: const CircleAvatar(
              backgroundColor: OlColors.primary,
              radius: 14,
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Today's Trip",
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          // ── No trip card ──────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 48, color: OlColors.textDisabled),
                  const SizedBox(height: 12),
                  Text(
                    'No trip assigned today',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: OlColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your manager will assign a delivery trip shortly.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: OlColors.textDisabled,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: null,   // disabled until trip exists
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Trip'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Generic Home (other roles) ────────────────────────────────────────────────
class GenericHome extends StatelessWidget {
  const GenericHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OrderLane Pro')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.laptop_mac, size: 56, color: OlColors.textDisabled),
            const SizedBox(height: 16),
            Text(
              'Use the web app',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'The mobile app is optimised for Sales Reps and Drivers. Please use the web app for full access.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OlColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: OlColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OlColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String   title;
  final String   body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: OlColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OlColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: OlColors.textDisabled),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: OlColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OlColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}
