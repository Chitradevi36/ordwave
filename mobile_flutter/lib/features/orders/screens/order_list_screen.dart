import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/sync_badge.dart';
import '../../../core/widgets/empty_state.dart';
import 'package:dio/dio.dart';

// ─── Types ─────────────────────────────────────────────────────────────────────
class _RemoteOrder {
  final int    id;
  final String orderNumber;
  final String status;
  final String customerName;
  final double totalAmount;
  final String createdAt;
  final String? creditDecision;

  const _RemoteOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.customerName,
    required this.totalAmount,
    required this.createdAt,
    this.creditDecision,
  });

  factory _RemoteOrder.fromJson(Map<String, dynamic> j) => _RemoteOrder(
        id:             j['id'] as int,
        orderNumber:    j['order_number'] as String,
        status:         j['status'] as String,
        customerName:   (j['customer'] as Map<String, dynamic>)['name'] as String,
        totalAmount:    (j['total_amount'] as num).toDouble(),
        createdAt:      j['created_at'] as String,
        creditDecision: j['credit_decision'] as String?,
      );
}

// ─── Tabs ──────────────────────────────────────────────────────────────────────
const _kTabs = ['All', 'Pending Sync', 'Submitted', 'Approved', 'Delivered'];

// ─── Providers ─────────────────────────────────────────────────────────────────
final _selectedTabProvider = StateProvider<int>((_) => 0);

final _localOrdersProvider = FutureProvider.autoDispose<List<PendingOrder>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.getAllLocalOrders();
});

final _remoteOrdersProvider =
    FutureProvider.autoDispose<List<_RemoteOrder>>((ref) async {
  final dio     = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  final orgId   = await storage.getOrganizationId();
  if (orgId == null) return [];

  try {
    final r = await dio.get<Map<String, dynamic>>(
      '/api/v1/sales_orders',
      queryParameters: {
        'per_page': '50',
        'sort_by':  'created_at',
        'sort_dir': 'desc',
      },
    );
    final list = r.data?['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => _RemoteOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException {
    return [];
  }
});

final _pendingSyncCountProvider = FutureProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.countPendingOrders();
});

// ─── Screen ────────────────────────────────────────────────────────────────────
class OrderListScreen extends ConsumerWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab   = ref.watch(_selectedTabProvider);
    final localOrders   = ref.watch(_localOrdersProvider);
    final remoteOrders  = ref.watch(_remoteOrdersProvider);
    final pendingCount  = ref.watch(_pendingSyncCountProvider);

    final pendingBadge = pendingCount.value ?? 0;

    return Scaffold(
      backgroundColor: OlColors.backgroundSubtle,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Orders', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(_remoteOrdersProvider);
              ref.invalidate(_localOrdersProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: OlColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Order',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        onPressed: () => context.push('/home/orders/new'),
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: OlColors.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_kTabs.length, (i) {
                  final isSelected = selectedTab == i;
                  final label = _kTabs[i];
                  final isPendingTab = i == 1;

                  return GestureDetector(
                    onTap: () =>
                        ref.read(_selectedTabProvider.notifier).state = i,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: isSelected
                              ? const BorderSide(
                                  color: OlColors.primary, width: 2)
                              : BorderSide.none,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? OlColors.primary
                                  : OlColors.textSecondary,
                            ),
                          ),
                          if (isPendingTab && pendingBadge > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: OlColors.warning,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$pendingBadge',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _buildTabContent(context, ref, selectedTab, localOrders, remoteOrders),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    WidgetRef ref,
    int tab,
    AsyncValue<List<PendingOrder>> localOrders,
    AsyncValue<List<_RemoteOrder>> remoteOrders,
  ) {
    switch (tab) {
      case 0: // All
        return _AllOrdersList(
            localOrders: localOrders, remoteOrders: remoteOrders);
      case 1: // Pending Sync
        return _LocalOrdersList(localOrders: localOrders);
      case 2: // Submitted
        return _RemoteOrdersList(
            remoteOrders: remoteOrders, statusFilter: 'submitted');
      case 3: // Approved
        return _RemoteOrdersList(
            remoteOrders: remoteOrders, statusFilter: 'approved');
      case 4: // Delivered
        return _RemoteOrdersList(
            remoteOrders: remoteOrders, statusFilter: 'delivered');
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── All Orders List ───────────────────────────────────────────────────────────
class _AllOrdersList extends StatelessWidget {
  const _AllOrdersList({
    required this.localOrders,
    required this.remoteOrders,
  });

  final AsyncValue<List<PendingOrder>>  localOrders;
  final AsyncValue<List<_RemoteOrder>>  remoteOrders;

  @override
  Widget build(BuildContext context) {
    if (localOrders.isLoading || remoteOrders.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final locals  = localOrders.value ?? [];
    final remotes = remoteOrders.value ?? [];
    final pending = locals.where((o) => o.status != 'synced').toList();

    if (pending.isEmpty && remotes.isEmpty) {
      return AppEmptyState.noOrders(
        onCreate: () => Navigator.of(context).pushNamed('/home/orders/new'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (pending.isNotEmpty) ...[
          const _SectionHeader(label: 'Offline / Pending Sync'),
          ...pending.map((o) => _LocalOrderCard(order: o)),
          const SizedBox(height: 8),
        ],
        if (remotes.isNotEmpty) ...[
          const _SectionHeader(label: 'Server Orders'),
          ...remotes.map((o) => _RemoteOrderCard(order: o)),
        ],
      ],
    );
  }
}

// ─── Local Orders List ─────────────────────────────────────────────────────────
class _LocalOrdersList extends StatelessWidget {
  const _LocalOrdersList({required this.localOrders});
  final AsyncValue<List<PendingOrder>> localOrders;

  @override
  Widget build(BuildContext context) {
    if (localOrders.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final orders = (localOrders.value ?? [])
        .where((o) => o.status != 'synced')
        .toList();

    if (orders.isEmpty) {
      return const AppEmptyState(
        icon: Icons.cloud_done_outlined,
        title: 'All caught up!',
        subtitle: 'No orders waiting to sync.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _LocalOrderCard(order: orders[i]),
    );
  }
}

// ─── Remote Orders List ────────────────────────────────────────────────────────
class _RemoteOrdersList extends StatelessWidget {
  const _RemoteOrdersList({
    required this.remoteOrders,
    required this.statusFilter,
  });

  final AsyncValue<List<_RemoteOrder>> remoteOrders;
  final String statusFilter;

  @override
  Widget build(BuildContext context) {
    if (remoteOrders.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final orders = (remoteOrders.value ?? [])
        .where((o) => o.status == statusFilter)
        .toList();

    if (orders.isEmpty) {
      return AppEmptyState.noOrders();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _RemoteOrderCard(order: orders[i]),
    );
  }
}

// ─── Local Order Card ──────────────────────────────────────────────────────────
class _LocalOrderCard extends StatelessWidget {
  const _LocalOrderCard({required this.order});
  final PendingOrder order;

  static SyncStatus _toSyncStatus(String status) {
    switch (status) {
      case 'syncing': return SyncStatus.syncing;
      case 'synced':  return SyncStatus.synced;
      case 'failed':  return SyncStatus.failed;
      default:        return SyncStatus.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OlColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OlColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SyncBadge(
            status: _toSyncStatus(order.status),
            compact: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.localOrderNumber,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: OlColors.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  order.customerName,
                  style: const TextStyle(
                      color: OlColors.textSecondary, fontSize: 12),
                ),
                if (order.errorMessage != null)
                  Text(
                    order.errorMessage!,
                    style: const TextStyle(
                        color: OlColors.error, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          SyncBadge(status: _toSyncStatus(order.status)),
        ],
      ),
    );
  }
}

// ─── Remote Order Card ─────────────────────────────────────────────────────────
class _RemoteOrderCard extends StatelessWidget {
  const _RemoteOrderCard({required this.order});
  final _RemoteOrder order;

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':  return OlColors.success;
      case 'on_hold':   return OlColors.warning;
      case 'rejected':
      case 'cancelled': return OlColors.error;
      default:          return OlColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OlColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OlColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: OlColors.primary,
                          fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            _statusColor(order.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.status.replaceAll('_', ' '),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(order.status)),
                      ),
                    ),
                    if (order.creditDecision != null &&
                        order.creditDecision != 'ok') ...[
                      const SizedBox(width: 4),
                      Icon(
                        order.creditDecision == 'blocked'
                            ? Icons.block
                            : Icons.warning_amber_rounded,
                        size: 14,
                        color: order.creditDecision == 'blocked'
                            ? OlColors.error
                            : OlColors.warning,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  order.customerName,
                  style: const TextStyle(
                      color: OlColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Total: ${order.totalAmount.toStringAsFixed(0)} rupees',
            child: Text(
              '\u20b9${order.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: OlColors.textPrimary,
                  fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: OlColors.textSecondary,
            letterSpacing: 0.8),
      ),
    );
  }
}
