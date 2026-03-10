import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/router/app_router.dart';
import '../models/pick_list.dart';
import '../providers/pick_provider.dart';

/// Shows all orders that are pending_pick or in picking state.
/// Intended for warehouse staff role.
class PickListScreen extends ConsumerWidget {
  const PickListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pickListsProvider);

    return Scaffold(
      backgroundColor: OlColors.background,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Pick List', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(pickListsProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: OlColors.error),
              const SizedBox(height: 12),
              Text(
                e.toString(),
                style: const TextStyle(color: OlColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(pickListsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (lists) {
          if (lists.isEmpty) {
            return const Center(
              child: _EmptyPick(),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pickListsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _PickListCard(
                pick: lists[i],
                onTap: () => context.push(
                  AppRoutes.pickDetail.replaceFirst(':id', lists[i].salesOrderId.toString()),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Pick list card ───────────────────────────────────────────────────────────

class _PickListCard extends StatelessWidget {
  const _PickListCard({required this.pick, required this.onTap});
  final PickList pick;
  final VoidCallback onTap;

  Color get _statusColor => switch (pick.status) {
        'picking'       => OlColors.warning,
        'picked'        => OlColors.success,
        'pick_confirmed' => OlColors.info,
        _               => OlColors.textSecondary, // pending_pick
      };

  String get _statusLabel => switch (pick.status) {
        'picking'        => 'In Progress',
        'picked'         => 'Picked',
        'pick_confirmed' => 'Confirmed',
        _                => 'Pending',
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OlColors.surfaceCard,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pick.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: OlColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                pick.orderNumber,
                style: const TextStyle(
                  color: OlColors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _StatChip(
                    label: '${pick.items.length} items',
                    color: OlColors.primary,
                  ),
                  const SizedBox(width: 8),
                  if (pick.pendingCount > 0)
                    _StatChip(
                      label: '${pick.pendingCount} pending',
                      color: OlColors.warning,
                    ),
                  if (pick.pickedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _StatChip(
                        label: '${pick.pickedCount} picked',
                        color: OlColors.success,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.color});
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
        ),
      );
}

class _EmptyPick extends StatelessWidget {
  const _EmptyPick();

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle_outline, size: 64, color: OlColors.success),
          SizedBox(height: 16),
          Text(
            'No pending picks',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: OlColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'All orders are picked or none need picking yet.',
            style: TextStyle(color: OlColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      );
}
