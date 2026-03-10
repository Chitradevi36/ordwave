import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/formatters.dart';
import '../providers/collection_provider.dart';

/// M5.3 — Recent collections list.
/// Shows last 7 days of payments from server + offline queue.
/// Includes sync status badges and retry capability.
class RecentCollectionsScreen extends ConsumerStatefulWidget {
  const RecentCollectionsScreen({super.key});

  @override
  ConsumerState<RecentCollectionsScreen> createState() =>
      _RecentCollectionsScreenState();
}

class _RecentCollectionsScreenState
    extends ConsumerState<RecentCollectionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentPaymentsProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state   = ref.watch(recentPaymentsProvider);
    final hasSync = state.localPayments.any(
        (p) => p.status == 'pending' || p.status == 'failed');

    return Scaffold(
      backgroundColor: OlColors.background,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Recent Collections',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (hasSync)
            IconButton(
              tooltip:  'Sync pending payments',
              onPressed: () =>
                  ref.read(recentPaymentsProvider.notifier).syncPending(),
              icon: const Icon(Icons.sync),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(recentPaymentsProvider.notifier).fetch(),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(RecentPaymentsState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final serverRows = state.serverPayments;
    final localRows  = state.localPayments
        .where((p) => p.status != 'synced') // don't duplicate synced ones
        .toList();

    if (serverRows.isEmpty && localRows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.payments_outlined, size: 48, color: OlColors.textSecondary),
              SizedBox(height: 12),
              Text(
                'No collections found',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'Collections from the last 7 days will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: OlColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── Offline queue section ──────────────────────────────────────
        if (localRows.isNotEmpty) ...[
          _sectionHeader('Offline Queue', count: localRows.length),
          const SizedBox(height: 8),
          ...localRows.map((p) => _LocalPaymentCard(payment: p)),
          const SizedBox(height: 20),
        ],

        // ── Server collections ─────────────────────────────────────────
        if (serverRows.isNotEmpty) ...[
          _sectionHeader('Last 7 Days', count: serverRows.length),
          const SizedBox(height: 8),
          ...serverRows.map((p) => _ServerPaymentCard(payment: p)),
        ],

        // ── Offline error banner ───────────────────────────────────────
        if (state.error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        OlColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: OlColors.warning.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off, color: OlColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.error!,
                    style: const TextStyle(fontSize: 12, color: OlColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(String label, {int count = 0}) => Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: OlColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color:        OlColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: OlColors.primary,
              ),
            ),
          ),
        ],
      );
}

// ── Server payment card ────────────────────────────────────────────────────────

class _ServerPaymentCard extends StatelessWidget {
  final RecentPayment payment;
  const _ServerPaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        OlColors.surface,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: OlColors.border),
        ),
        child: Row(
          children: [
            // Mode icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        OlColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _modeIcon(payment.paymentMode),
                color: OlColors.success,
                size:  20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(payment.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize:   14,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    '${payment.paymentNumber} • ${payment.receivedDate} • ${payment.paymentMode.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 11,
                      color:    OlColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(payment.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   15,
                    color:      OlColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                _SyncBadge(status: 'synced'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _modeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'upi':    return Icons.phone_android;
      case 'cheque': return Icons.receipt_long;
      case 'neft':
      case 'rtgs':   return Icons.account_balance;
      default:       return Icons.payments_outlined;
    }
  }
}

// ── Local (offline) payment card ───────────────────────────────────────────────

class _LocalPaymentCard extends StatelessWidget {
  final dynamic payment; // PendingPayment from Drift
  const _LocalPaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        OlColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: payment.status == 'failed'
                ? OlColors.error.withOpacity(0.4)
                : OlColors.warning.withOpacity(0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        OlColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                color: OlColors.warning,
                size:  20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.customerName as String? ?? 'Customer',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(payment.receivedDate as String).substring(0, 10)} • ${(payment.paymentMode as String).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: OlColors.textSecondary,
                    ),
                  ),
                  if (payment.errorMessage != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      payment.errorMessage as String,
                      style: const TextStyle(fontSize: 10, color: OlColors.error),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(payment.amount as num),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize:   15,
                  ),
                ),
                const SizedBox(height: 2),
                _SyncBadge(status: payment.status as String),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sync badge ─────────────────────────────────────────────────────────────────

class _SyncBadge extends StatelessWidget {
  final String status;
  const _SyncBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'synced':
        color = OlColors.success; label = '✓ Synced';
      case 'syncing':
        color = OlColors.info;    label = '… Syncing';
      case 'failed':
        color = OlColors.error;   label = '✗ Failed';
      default:
        color = OlColors.warning; label = '⏳ Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize:   10,
          fontWeight: FontWeight.w600,
          color:      color,
        ),
      ),
    );
  }
}
