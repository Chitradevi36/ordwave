import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/success_overlay.dart';
import '../models/cart.dart';
import '../providers/cart_provider.dart';

// ── Retailer credit lookup ─────────────────────────────────────────────────────
final _retailerCreditProvider =
    FutureProvider.family<Retailer?, int>((ref, customerId) async {
  final db = ref.watch(appDatabaseProvider);
  return db.getRetailerById(customerId);
});

// ─── Screen ────────────────────────────────────────────────────────────────────
class CartReviewScreen extends ConsumerStatefulWidget {
  const CartReviewScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.branchId,
  });

  final int    customerId;
  final String customerName;
  final int    branchId;

  @override
  ConsumerState<CartReviewScreen> createState() => _CartReviewScreenState();
}

class _CartReviewScreenState extends ConsumerState<CartReviewScreen> {
  bool _submitting = false;

  Future<void> _submit() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final result = await ref.read(cartProvider.notifier).submitOrder(
            customerId:   widget.customerId,
            customerName: widget.customerName,
            branchId:     widget.branchId,
          );

      if (mounted) {
        showSuccessOverlay(
          context,
          title: 'Order Submitted!',
          subtitle: 'Your order is now pending approval.',
          displayDuration: const Duration(milliseconds: 1800),
          onDone: () => context.push('/home/orders/new/credit-result', extra: result),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: OlColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: OlColors.backgroundSubtle,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Review Cart', style: TextStyle(color: Colors.white, fontSize: 16)),
            Text(
              widget.customerName,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: cart.isEmpty
          ? const Center(
              child: Text('Cart is empty.', style: TextStyle(color: OlColors.textSecondary)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Cart items
                ...cart.lines.map((line) => _CartLineCard(line: line)),

                const SizedBox(height: 16),

                // Customer credit status
                _CustomerCreditCard(customerId: widget.customerId),

                const SizedBox(height: 12),

                // Order summary card
                Container(
                  decoration: BoxDecoration(
                    color: OlColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: OlColors.border),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Summary',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: OlColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      _SummaryRow(
                        label: 'Items',
                        value: '${cart.lines.length} (${cart.itemCount} units)',
                      ),
                      const Divider(height: 20),
                      _SummaryRow(
                        label: 'Subtotal',
                        value: '₹${cart.subtotal.toStringAsFixed(2)}',
                        bold: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 80), // space for bottom bar
              ],
            ),

      // Submit button
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: OlColors.primary,
              disabledBackgroundColor: OlColors.primary.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: (cart.isEmpty || _submitting) ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Submit Order',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Customer Credit Card ───────────────────────────────────────────────────────
class _CustomerCreditCard extends ConsumerWidget {
  const _CustomerCreditCard({required this.customerId});
  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_retailerCreditProvider(customerId));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data:    (retailer) {
        if (retailer == null) return const SizedBox.shrink();

        final outstanding = retailer.outstanding;
        final creditLimit = retailer.creditLimit;
        final status      = retailer.creditStatus ?? 'ok';

        Color statusColor;
        IconData statusIcon;
        switch (status) {
          case 'blocked':
            statusColor = OlColors.error;
            statusIcon  = Icons.block_rounded;
            break;
          case 'hold':
          case 'overdue':
            statusColor = OlColors.warning;
            statusIcon  = Icons.warning_amber_rounded;
            break;
          default:
            statusColor = OlColors.success;
            statusIcon  = Icons.check_circle_rounded;
        }

        return Container(
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      color: statusColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Customer Credit',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        fontSize: 13),
                  ),
                  const Spacer(),
                  Icon(statusIcon, color: statusColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CreditStat(
                      label:  'Outstanding',
                      value:  '₹${outstanding.toStringAsFixed(0)}',
                      color:  outstanding > 0 ? OlColors.warning : OlColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CreditStat(
                      label:  'Credit Limit',
                      value:  creditLimit > 0 ? '₹${creditLimit.toStringAsFixed(0)}' : 'None',
                      color:  OlColors.textSecondary,
                    ),
                  ),
                  if (creditLimit > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CreditStat(
                        label: 'Available',
                        value: '₹${(creditLimit - outstanding).clamp(0, creditLimit).toStringAsFixed(0)}',
                        color: (creditLimit - outstanding) > 0
                            ? OlColors.success
                            : OlColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CreditStat extends StatelessWidget {
  const _CreditStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: OlColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

// ─── Cart Line Card ────────────────────────────────────────────────────────────
class _CartLineCard extends ConsumerWidget {
  const _CartLineCard({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);

    return Dismissible(
      key: ValueKey(line.productId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: OlColors.error,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => notifier.removeFromCart(line.productId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: OlColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OlColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.productName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: OlColors.textPrimary,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${line.productSku}  ·  ₹${line.unitPrice.toStringAsFixed(2)}/${line.unit}',
                    style: const TextStyle(
                        fontSize: 11, color: OlColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Qty stepper
            Row(
              children: [
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.remove_circle_outline),
                  color: OlColors.primary,
                  onPressed: () => notifier.updateQty(line.productId, line.qty - 1),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${line.qty}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.add_circle_outline),
                  color: OlColors.primary,
                  onPressed: () => notifier.updateQty(line.productId, line.qty + 1),
                ),
              ],
            ),

            // Line total
            const SizedBox(width: 8),
            Text(
              '₹${line.lineTotal.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: OlColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Row ───────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool   bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)
        : const TextStyle(color: OlColors.textSecondary);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
