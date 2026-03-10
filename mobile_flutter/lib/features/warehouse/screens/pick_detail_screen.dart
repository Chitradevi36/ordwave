import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../models/pick_list.dart';
import '../providers/pick_provider.dart';

/// Full pick detail screen — shows each item in the pick list and allows
/// warehouse staff to enter the qty picked per item, then submit.
class PickDetailScreen extends ConsumerStatefulWidget {
  const PickDetailScreen({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<PickDetailScreen> createState() => _PickDetailScreenState();
}

class _PickDetailScreenState extends ConsumerState<PickDetailScreen> {
  /// Local mutable copies of qty_picked keyed by item id
  final Map<int, TextEditingController> _controllers = {};
  bool _submitAttempted = false;

  void _initControllers(List<PickListItem> items) {
    for (final item in items) {
      if (!_controllers.containsKey(item.id)) {
        final prefilledQty = item.qtyPicked > 0
            ? item.qtyPicked.toString()
            : item.qtyRequested.toString();
        _controllers[item.id] = TextEditingController(text: prefilledQty);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(PickList pickList) async {
    setState(() => _submitAttempted = true);
    final items = pickList.items.map((item) {
      final raw = _controllers[item.id]?.text ?? '0';
      final qty = double.tryParse(raw) ?? 0;
      return item..qtyPicked = qty;
    }).toList();

    final ok = await ref
        .read(pickNotifierProvider.notifier)
        .submitPick(salesOrderId: widget.orderId, items: items);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick submitted successfully!'),
          backgroundColor: OlColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async     = ref.watch(pickListDetailProvider(widget.orderId));
    final pickState = ref.watch(pickNotifierProvider);

    return Scaffold(
      backgroundColor: OlColors.background,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Pick Items', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(
          child: Text(e.toString(), style: const TextStyle(color: OlColors.error)),
        ),
        data: (pickList) {
          _initControllers(pickList.items);
          final canSubmit = pickList.status == 'pending_pick' || pickList.status == 'picking';

          return Column(
            children: [
              // Order header
              _OrderHeader(pickList: pickList),

              // Items list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: pickList.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final item = pickList.items[i];
                    return _PickItemRow(
                      item:       item,
                      controller: _controllers[item.id]!,
                      enabled:    canSubmit,
                    );
                  },
                ),
              ),

              // Error banner
              if (pickState.error != null)
                Container(
                  color: OlColors.error50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: OlColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pickState.error!,
                          style: const TextStyle(color: OlColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Submit button
              if (canSubmit)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: pickState.loading ? null : () => _submit(pickList),
                        icon: pickState.loading
                            ? const SizedBox(
                                height: 16,
                                width:  16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          pickState.loading ? 'Submitting…' : 'Submit Pick',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OlColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Already picked notice
              if (!canSubmit)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, color: OlColors.textSecondary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'This pick is ${pickList.status.replaceAll('_', ' ')}',
                        style: const TextStyle(color: OlColors.textSecondary),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Order header ─────────────────────────────────────────────────────────────

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.pickList});
  final PickList pickList;

  @override
  Widget build(BuildContext context) => Container(
        color: OlColors.surfaceCard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pickList.customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: OlColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pickList.orderNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      color: OlColors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${pickList.items.length} items',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: OlColors.primary,
                  ),
                ),
                if (pickList.pickedByName != null)
                  Text(
                    'By: ${pickList.pickedByName}',
                    style: const TextStyle(fontSize: 11, color: OlColors.textSecondary),
                  ),
              ],
            ),
          ],
        ),
      );
}

// ─── Individual item row ──────────────────────────────────────────────────────

class _PickItemRow extends StatelessWidget {
  const _PickItemRow({
    required this.item,
    required this.controller,
    required this.enabled,
  });

  final PickListItem          item;
  final TextEditingController controller;
  final bool                  enabled;

  Color get _rowBg {
    if (!enabled) return OlColors.surfaceCard;
    if (item.isPicked) return OlColors.success50;
    if (item.isShort)  return OlColors.error50;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _rowBg,
        border: Border.all(color: OlColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Item info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: OlColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.productSku,
                  style: const TextStyle(
                    fontSize: 11,
                    color: OlColors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
                if (item.locationCode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: OlColors.info),
                        const SizedBox(width: 3),
                        Text(
                          item.locationCode!,
                          style: const TextStyle(fontSize: 11, color: OlColors.info),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Requested qty
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Req: ${item.qtyRequested}',
                style: const TextStyle(
                  fontSize: 12,
                  color: OlColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              // Qty picked input
              SizedBox(
                width: 90,
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: 'Picked',
                    labelStyle:
                        const TextStyle(fontSize: 11, color: OlColors.textSecondary),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: OlColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: OlColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide:
                          const BorderSide(color: OlColors.primary, width: 1.5),
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OlColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
