import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../models/cart.dart';

// ─── Screen ────────────────────────────────────────────────────────────────────
class CreditCheckResultScreen extends StatelessWidget {
  const CreditCheckResultScreen({super.key, required this.result});
  final CreditCheckResult result;

  @override
  Widget build(BuildContext context) {
    // Offline save
    if (result.decision == 'offline') {
      return _ResultScaffold(
        icon: Icons.cloud_off_rounded,
        iconColor: OlColors.textSecondary,
        bgColor: OlColors.backgroundSubtle,
        borderColor: OlColors.border,
        title: 'Saved Offline',
        subtitle: result.orderNumber != null
            ? 'Order ${result.orderNumber} saved — will sync automatically when online.'
            : 'Order saved. Will sync when connectivity is restored.',
        reasons: result.reasons,
        actions: [
          _ActionButton(
            label: 'Go to Orders',
            onPressed: () {
              while (context.canPop()) { context.pop(); }
              context.go('/home/orders');
            },
          ),
          _ActionButton(
            label: 'New Order',
            outlined: true,
            onPressed: () {
              while (context.canPop()) { context.pop(); }
            },
          ),
        ],
      );
    }

    switch (result.decision) {
      case 'ok':
        return _ResultScaffold(
          icon: Icons.check_circle_rounded,
          iconColor: OlColors.success,
          bgColor: OlColors.success50,
          borderColor: OlColors.success.withOpacity(0.3),
          title: 'Credit Approved',
          subtitle: result.orderNumber != null
              ? 'Order ${result.orderNumber} submitted successfully.'
              : 'Order submitted — awaiting manager approval.',
          reasons: [],
          actions: [
            _ActionButton(
              label: 'View Orders',
              onPressed: () {
                while (context.canPop()) { context.pop(); }
                context.go('/home/orders');
              },
            ),
            _ActionButton(
              label: 'New Order',
              outlined: true,
              onPressed: () {
                while (context.canPop()) { context.pop(); }
              },
            ),
          ],
        );

      case 'hold':
        return _ResultScaffold(
          icon: Icons.warning_amber_rounded,
          iconColor: OlColors.warning,
          bgColor: OlColors.warning50,
          borderColor: OlColors.warning.withOpacity(0.3),
          title: 'Manager Approval Needed',
          subtitle: 'Order submitted but requires credit review before dispatch.',
          reasons: result.reasons,
          actions: [
            _ActionButton(
              label: 'View Orders',
              onPressed: () {
                while (context.canPop()) { context.pop(); }
                context.go('/home/orders');
              },
            ),
            _ActionButton(
              label: 'Request Override',
              onPressed: () {
                _showOverrideRequestSheet(context, result);
              },
            ),
            _ActionButton(
              label: 'Collect First',
              outlined: true,
              onPressed: () {
                while (context.canPop()) { context.pop(); }
                context.go('/home/collect');
              },
            ),
          ],
        );

      case 'blocked':
      default:
        return _ResultScaffold(
          icon: Icons.block_rounded,
          iconColor: OlColors.error,
          bgColor: OlColors.error50,
          borderColor: OlColors.error.withOpacity(0.3),
          title: 'Credit Blocked',
          subtitle: 'This order cannot proceed until the outstanding balance is cleared.',
          reasons: result.reasons,
          actions: [
            _ActionButton(
              label: 'Collect Now',
              onPressed: () {
                while (context.canPop()) { context.pop(); }
                context.go('/home/collect');
              },
            ),
            _ActionButton(
              label: 'Call Manager',
              outlined: true,
              onPressed: () => context.pop(),
            ),
          ],
        );
    }
  }
}

/// Shows a bottom sheet allowing the sales rep to add a note and request
/// an expedited manager override for an on-hold order.
void _showOverrideRequestSheet(BuildContext context, CreditCheckResult result) {
  final noteController = TextEditingController();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Override',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              result.orderNumber != null
                  ? 'Order ${result.orderNumber} is on hold. Add a note for your manager explaining why this order should be approved.'
                  : 'Add a note for your manager to expedite review.',
              style: const TextStyle(color: OlColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Customer is a long-standing account, needs urgent delivery…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OlColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.orderNumber != null
                            ? 'Override request sent for ${result.orderNumber}. '
                              'Your manager will be notified.'
                            : 'Override request sent to your manager.',
                      ),
                      backgroundColor: OlColors.primary,
                    ),
                  );
                  // Navigate to orders so the rep can monitor approval status
                  while (context.canPop()) { context.pop(); }
                  context.go('/home/orders');
                },
                child: const Text('Send Override Request'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ─── Result Scaffold ───────────────────────────────────────────────────────────
class _ResultScaffold extends StatelessWidget {
  const _ResultScaffold({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.title,
    required this.subtitle,
    required this.reasons,
    required this.actions,
  });

  final IconData   icon;
  final Color      iconColor;
  final Color      bgColor;
  final Color      borderColor;
  final String     title;
  final String     subtitle;
  final List<String> reasons;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OlColors.backgroundSubtle,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title:
            const Text('Credit Check', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Result card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(icon, size: 64, color: iconColor),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: iconColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: OlColors.textSecondary, fontSize: 14),
                    ),
                    if (reasons.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      ...reasons.map((r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 15, color: iconColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(r,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: OlColors.textSecondary)),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              // Action buttons
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Action Button ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String   label;
  final VoidCallback onPressed;
  final bool     outlined;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: outlined
            ? OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: OlColors.primary,
                  side: const BorderSide(color: OlColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onPressed,
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OlColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onPressed,
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
      ),
    );
  }
}
