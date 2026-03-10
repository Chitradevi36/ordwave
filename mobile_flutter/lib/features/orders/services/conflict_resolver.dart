import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../orders/services/sync_engine.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CONFLICT ACTIONS
// ═══════════════════════════════════════════════════════════════════════════════

enum ConflictAction {
  cancelOrder,
  requestOverride,
  acceptNewPrices,
  sendAsAdvance,
  adjustAmount,
  dismiss,
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONFLICT RESOLVER SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

class ConflictResolver {
  const ConflictResolver._();

  /// Shows the appropriate dialog for the given [conflict] and returns the
  /// user's chosen action.  Returns [ConflictAction.dismiss] if dismissed.
  static Future<ConflictAction> resolve(
    BuildContext context,
    SyncConflict conflict,
  ) async {
    if (conflict.isAutoResolvable) return ConflictAction.dismiss;

    return switch (conflict.type) {
      ConflictType.customerBlocked =>
          _showCustomerBlockedDialog(context, conflict),
      ConflictType.priceChanged =>
          _showPriceChangedDialog(context, conflict),
      ConflictType.paymentExceedsOutstanding =>
          _showPaymentExceedsDialog(context, conflict),
      _ => _showGenericConflictDialog(context, conflict),
    };
  }

  // ── Customer blocked ────────────────────────────────────────────────────────

  static Future<ConflictAction> _showCustomerBlockedDialog(
    BuildContext ctx,
    SyncConflict conflict,
  ) async {
    final result = await showModalBottomSheet<ConflictAction>(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ConflictSheet(
        icon:        Icons.block_outlined,
        iconColor:   OlColors.error,
        title:       'Customer Credit Blocked',
        body:        conflict.message +
            '\n\nYou can cancel this order, or flag it for manager override.',
        actions: const [
          _ConflictOption(
            value:  ConflictAction.cancelOrder,
            label:  'Cancel Order',
            color:  OlColors.error,
            filled: true,
          ),
          _ConflictOption(
            value:  ConflictAction.requestOverride,
            label:  'Request Override',
            color:  OlColors.primary,
            filled: false,
          ),
        ],
      ),
    );
    return result ?? ConflictAction.dismiss;
  }

  // ── Price changed ───────────────────────────────────────────────────────────

  static Future<ConflictAction> _showPriceChangedDialog(
    BuildContext ctx,
    SyncConflict conflict,
  ) async {
    final oldTotal = (conflict.serverData['old_total'] as num?)?.toDouble();
    final newTotal = (conflict.serverData['new_total'] as num?)?.toDouble();

    final body = StringBuffer(conflict.message);
    if (oldTotal != null && newTotal != null) {
      body.write('\n\nOriginal total: ₹${oldTotal.toStringAsFixed(2)}'
          '\nUpdated total:  ₹${newTotal.toStringAsFixed(2)}');
    }

    final result = await showModalBottomSheet<ConflictAction>(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ConflictSheet(
        icon:      Icons.price_change_outlined,
        iconColor: OlColors.warning,
        title:     'Prices Updated',
        body:      body.toString(),
        actions: const [
          _ConflictOption(
            value:  ConflictAction.acceptNewPrices,
            label:  'Accept New Prices',
            color:  OlColors.primary,
            filled: true,
          ),
          _ConflictOption(
            value:  ConflictAction.cancelOrder,
            label:  'Cancel Order',
            color:  OlColors.error,
            filled: false,
          ),
        ],
      ),
    );
    return result ?? ConflictAction.dismiss;
  }

  // ── Payment exceeds outstanding ─────────────────────────────────────────────

  static Future<ConflictAction> _showPaymentExceedsDialog(
    BuildContext ctx,
    SyncConflict conflict,
  ) async {
    final outstanding = (conflict.serverData['outstanding'] as num?)?.toDouble();
    final amount      = (conflict.serverData['amount'] as num?)?.toDouble();

    final body = StringBuffer(conflict.message);
    if (outstanding != null) {
      body.write('\n\nCurrent outstanding: ₹${outstanding.toStringAsFixed(2)}');
    }
    if (amount != null && outstanding != null) {
      body.write('\nExcess amount:       ₹${(amount - outstanding).toStringAsFixed(2)} (would become advance)');
    }

    final result = await showModalBottomSheet<ConflictAction>(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ConflictSheet(
        icon:      Icons.payments_outlined,
        iconColor: OlColors.warning,
        title:     'Payment Exceeds Outstanding',
        body:      body.toString(),
        actions: const [
          _ConflictOption(
            value:  ConflictAction.sendAsAdvance,
            label:  'Send as Advance',
            color:  OlColors.primary,
            filled: true,
          ),
          _ConflictOption(
            value:  ConflictAction.adjustAmount,
            label:  'Adjust Amount',
            color:  OlColors.secondary,
            filled: false,
          ),
          _ConflictOption(
            value:  ConflictAction.cancelOrder,
            label:  'Cancel',
            color:  OlColors.error,
            filled: false,
          ),
        ],
      ),
    );
    return result ?? ConflictAction.dismiss;
  }

  // ── Generic ─────────────────────────────────────────────────────────────────

  static Future<ConflictAction> _showGenericConflictDialog(
    BuildContext ctx,
    SyncConflict conflict,
  ) async {
    final result = await showModalBottomSheet<ConflictAction>(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ConflictSheet(
        icon:      Icons.sync_problem_outlined,
        iconColor: OlColors.warning,
        title:     'Sync Conflict',
        body:      conflict.message,
        actions: const [
          _ConflictOption(
            value:  ConflictAction.dismiss,
            label:  'Dismiss',
            color:  OlColors.primary,
            filled: true,
          ),
        ],
      ),
    );
    return result ?? ConflictAction.dismiss;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UI COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

class _ConflictOption {
  final ConflictAction value;
  final String         label;
  final Color          color;
  final bool           filled;

  const _ConflictOption({
    required this.value,
    required this.label,
    required this.color,
    required this.filled,
  });
}

class _ConflictSheet extends StatelessWidget {
  const _ConflictSheet({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.actions,
  });

  final IconData            icon;
  final Color               iconColor;
  final String              title;
  final String              body;
  final List<_ConflictOption> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: OlColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Icon
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: iconColor),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: OlColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Body
            Text(
              body,
              style: const TextStyle(fontSize: 14, color: OlColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Action buttons
            ...actions.map((opt) {
              if (opt.filled) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(opt.value),
                      style: FilledButton.styleFrom(
                        backgroundColor: opt.color,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(opt.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(opt.value),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: opt.color,
                      side: BorderSide(color: opt.color.withOpacity(0.4)),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(opt.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: opt.color)),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
