import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/local_db/app_database.dart';
import '../../orders/services/sync_service.dart';

// Compatibility shim — sync screen was written with AppColors; map to OlColors.
abstract class AppColors {
  static const background   = OlColors.background;
  static const surface      = OlColors.surface;
  static const danger       = OlColors.error;
  static const warning      = OlColors.warning;
  static const success      = OlColors.success;
  static const textSecondary = OlColors.textSecondary;
  static const accent       = OlColors.primary;
}

// ── Sync state model ──────────────────────────────────────────────────────────

class SyncEntityState {
  final String  entityType;
  final String  label;
  final IconData icon;
  final int     pendingCount;
  final int     failedCount;
  final String? lastSyncedAt;
  final bool    isSyncing;

  const SyncEntityState({
    required this.entityType,
    required this.label,
    required this.icon,
    required this.pendingCount,
    required this.failedCount,
    this.lastSyncedAt,
    this.isSyncing = false,
  });

  SyncEntityState copyWith({bool? isSyncing}) => SyncEntityState(
    entityType:   entityType,
    label:        label,
    icon:         icon,
    pendingCount: pendingCount,
    failedCount:  failedCount,
    lastSyncedAt: lastSyncedAt,
    isSyncing:    isSyncing ?? this.isSyncing,
  );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final syncCenterProvider = FutureProvider.autoDispose<List<SyncEntityState>>((ref) async {
  final db = ref.watch(appDatabaseProvider);

  // Load counts in parallel
  final results = await Future.wait([
    // PendingOrders pending/failed
    db.getPendingOrders(),
    // PendingPayments pending/failed
    db.getPendingPayments(),
    // TripStops unsynced
    db.getUnsyncedStops(),
    // Sync metadata
    db.getSyncMeta('retailers'),
    db.getSyncMeta('products'),
  ]);

  final allOrders       = results[0] as List;
  final allPayments     = results[1] as List;
  final allStops        = results[2] as List;
  final retailersMeta   = results[3] as SyncMetadatum?;
  final productsMeta    = results[4] as SyncMetadatum?;

  final ordersPending   = allOrders.where((o)   => (o.status as String) == 'pending').length;
  final ordersFailed    = allOrders.where((o)   => (o.status as String) == 'failed').length;
  final paymentsPending = allPayments.where((p) => (p.status as String) == 'pending').length;
  final paymentsFailed  = allPayments.where((p) => (p.status as String) == 'failed').length;
  final stopsPending    = allStops.length;

  return [
    SyncEntityState(
      entityType:   'orders',
      label:        'Offline Orders',
      icon:         Icons.receipt_long_outlined,
      pendingCount: ordersPending,
      failedCount:  ordersFailed,
      lastSyncedAt: null,
    ),
    SyncEntityState(
      entityType:   'payments',
      label:        'Offline Payments',
      icon:         Icons.payments_outlined,
      pendingCount: paymentsPending,
      failedCount:  paymentsFailed,
      lastSyncedAt: null,
    ),
    SyncEntityState(
      entityType:   'trip_stops',
      label:        'Delivery Stops',
      icon:         Icons.local_shipping_outlined,
      pendingCount: stopsPending,
      failedCount:  0,
      lastSyncedAt: null,
    ),
    SyncEntityState(
      entityType:   'retailers',
      label:        'Retailers Cache',
      icon:         Icons.store_outlined,
      pendingCount: 0,
      failedCount:  0,
      lastSyncedAt: retailersMeta?.lastSyncedAt,
    ),
    SyncEntityState(
      entityType:   'products',
      label:        'Products Cache',
      icon:         Icons.inventory_2_outlined,
      pendingCount: 0,
      failedCount:  0,
      lastSyncedAt: productsMeta?.lastSyncedAt,
    ),
  ];
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class SyncCenterScreen extends ConsumerStatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  ConsumerState<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends ConsumerState<SyncCenterScreen> {
  bool _syncing = false;
  String? _syncError;
  String? _syncSuccess;

  Future<void> _syncAll() async {
    setState(() { _syncing = true; _syncError = null; _syncSuccess = null; });
    try {
      await SyncService.triggerImmediateSync();
      setState(() { _syncing = false; _syncSuccess = 'Sync completed successfully.'; });
    } catch (e) {
      setState(() { _syncing = false; _syncError = e.toString(); });
    } finally {
      ref.invalidate(syncCenterProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncAsync = ref.watch(syncCenterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Sync Center', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(syncCenterProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status banner
          if (_syncError != null)
            _Banner(message: _syncError!, color: AppColors.danger, icon: Icons.error_outline,
                onDismiss: () => setState(() => _syncError = null)),
          if (_syncSuccess != null)
            _Banner(message: _syncSuccess!, color: AppColors.success, icon: Icons.check_circle_outline,
                onDismiss: () => setState(() => _syncSuccess = null)),

          // Sync Now button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _syncing ? null : _syncAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _syncing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync),
                label: Text(_syncing ? 'Syncing…' : 'Sync Now', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ),

          // Entity list
          Expanded(
            child: syncAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (entities) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: entities.length,
                itemBuilder: (ctx, i) => _EntityCard(
                  entity: entities[i],
                  onRefresh: () => ref.invalidate(syncCenterProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Entity Card ───────────────────────────────────────────────────────────────

class _EntityCard extends ConsumerWidget {
  const _EntityCard({required this.entity, required this.onRefresh});
  final SyncEntityState entity;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPending = entity.pendingCount > 0;
    final hasFailed  = entity.failedCount  > 0;

    String statusLabel;
    Color  statusColor;
    IconData statusIcon;

    if (hasFailed) {
      statusLabel = '${entity.failedCount} failed';
      statusColor = AppColors.danger;
      statusIcon  = Icons.error_outline;
    } else if (hasPending) {
      statusLabel = '${entity.pendingCount} pending';
      statusColor = AppColors.warning;
      statusIcon  = Icons.schedule_outlined;
    } else {
      statusLabel = 'Up to date';
      statusColor = AppColors.success;
      statusIcon  = Icons.check_circle_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(entity.icon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entity.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      if (entity.lastSyncedAt != null)
                        Text(
                          'Last synced: ${_formatDate(entity.lastSyncedAt!)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        )
                      else if (entity.pendingCount == 0 && entity.failedCount == 0)
                        const Text('Synced', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 4),
                    Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            // Per-item discard button for failed orders/payments
            if (hasFailed &&
                (entity.entityType == 'orders' || entity.entityType == 'payments')) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showDiscardDialog(context, ref, entity, onRefresh),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 14),
                  label: const Text('View & Discard Failed'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.length >= 10 ? iso.substring(0, 10) : iso;
    }
  }
}

Future<void> _showDiscardDialog(
  BuildContext context,
  WidgetRef ref,
  SyncEntityState entity,
  VoidCallback onRefresh,
) async {
  final db = ref.read(appDatabaseProvider);
  List<dynamic> failedItems;

  if (entity.entityType == 'orders') {
    final orders = await db.getPendingOrders();
    failedItems = orders.where((o) => o.status == 'failed').toList();
  } else {
    final payments = await db.getPendingPayments();
    failedItems = payments.where((p) => p.status == 'failed').toList();
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => _DiscardItemsDialog(
      entityType: entity.entityType,
      items: failedItems,
      onDiscard: (localId) async {
        if (entity.entityType == 'orders') {
          await db.discardOrder(localId);
        } else {
          await db.discardPayment(localId);
        }
        onRefresh();
      },
    ),
  );
}

class _DiscardItemsDialog extends StatefulWidget {
  const _DiscardItemsDialog({
    required this.entityType,
    required this.items,
    required this.onDiscard,
  });

  final String entityType;
  final List<dynamic> items;
  final Future<void> Function(int localId) onDiscard;

  @override
  State<_DiscardItemsDialog> createState() => _DiscardItemsDialogState();
}

class _DiscardItemsDialogState extends State<_DiscardItemsDialog> {
  late final List<dynamic> _items;
  bool _discarding = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  Future<void> _discard(int index) async {
    setState(() => _discarding = true);
    final item = _items[index];
    final localId = (item.localId as int);
    try {
      await widget.onDiscard(localId);
      setState(() => _items.removeAt(index));
    } finally {
      if (mounted) setState(() => _discarding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOrder = widget.entityType == 'orders';
    return AlertDialog(
      title: Text('Failed ${isOrder ? "Orders" : "Payments"}'),
      content: SizedBox(
        width: double.maxFinite,
        child: _items.isEmpty
            ? const Text('No failed items remaining.')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final item = _items[i];
                  final label = isOrder
                      ? (item.localOrderNumber as String)
                      : '₹${(item.amount as double).toStringAsFixed(2)} — ${item.customerName as String}';
                  final error = item.errorMessage as String? ?? 'Unknown error';
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(label, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(error, style: TextStyle(fontSize: 11, color: AppColors.danger)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppColors.danger,
                      tooltip: 'Discard',
                      onPressed: _discarding ? null : () => _discard(i),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// ── Banner ─────────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.color, required this.icon, required this.onDismiss});
  final String     message;
  final Color      color;
  final IconData   icon;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(fontSize: 13, color: color))),
          GestureDetector(onTap: onDismiss, child: Icon(Icons.close, size: 16, color: color)),
        ],
      ),
    );
  }
}
