import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../models/trip.dart';
import '../providers/trip_provider.dart';

/// M4.7 — Record cash / UPI / cheque collection at a delivery stop.
class CashCollectionScreen extends ConsumerStatefulWidget {
  const CashCollectionScreen({super.key, required this.tripId, required this.stop});
  final int          tripId;
  final TripStopItem stop;

  @override
  ConsumerState<CashCollectionScreen> createState() => _CashCollectionScreenState();
}

class _CashCollectionScreenState extends ConsumerState<CashCollectionScreen> {
  String _mode = 'cash';
  final _amountCtrl    = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl     = TextEditingController();

  // Estimated invoice total (sum of line totals)
  double get _estimatedTotal => widget.stop.lines.fold(
    0.0, (sum, l) => sum + l.qtyOrdered * l.unitPrice,
  );

  @override
  void initState() {
    super.initState();
    // Pre-fill with the estimated invoice total
    _amountCtrl.text = _estimatedTotal.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.')),
      );
      return;
    }

    final notifier = ref.read(recordCashProvider.notifier);
    final ok = await notifier.recordCash(
      tripId:      widget.tripId,
      stopId:      widget.stop.id,
      amount:      amount,
      paymentMode: _mode,
      reference:   _referenceCtrl.text.trim().isNotEmpty ? _referenceCtrl.text.trim() : null,
      notes:       _notesCtrl.text.trim().isNotEmpty      ? _notesCtrl.text.trim()      : null,
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment of ₹${amount.toStringAsFixed(2)} recorded!'),
          backgroundColor: OlColors.success,
        ),
      );
      context.pop();
    } else {
      final err = ref.read(recordCashProvider).error ?? 'Error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $err'), backgroundColor: OlColors.error),
      );
      ref.read(recordCashProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordCashProvider);

    return Scaffold(
      backgroundColor: OlColors.background,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Collect Payment', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Customer info ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: OlColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.store_outlined, color: OlColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.stop.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Est. Total', style: TextStyle(fontSize: 11, color: OlColors.textSecondary)),
                        Text(
                          '₹${_estimatedTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: OlColors.primary, fontSize: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Payment mode ──
            const Text('PAYMENT MODE', style: _sectionLabel),
            const SizedBox(height: 8),
            _ModeSelector(selected: _mode, onChanged: (v) => setState(() => _mode = v)),
            const SizedBox(height: 20),

            // ── Amount ──
            const Text('AMOUNT RECEIVED', style: _sectionLabel),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: OlColors.textSecondary),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // ── Reference (UPI txn / cheque number) ──
            if (_mode != 'cash') ...[
              const Text('REFERENCE NUMBER', style: _sectionLabel),
              const SizedBox(height: 8),
              TextField(
                controller: _referenceCtrl,
                decoration: InputDecoration(
                  hintText: _mode == 'upi' ? 'UPI transaction ID' : 'Cheque number',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Notes ──
            const Text('NOTES (OPTIONAL)', style: _sectionLabel),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Any notes about this collection',
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OlColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: state.loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  state.loading ? 'Saving…' : 'Record Payment',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                onPressed: state.loading ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: OlColors.textSecondary,
    letterSpacing: 0.8,
  );
}

// ─── Payment Mode Selector ────────────────────────────────────────────────────

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onChanged});
  final String                selected;
  final ValueChanged<String>  onChanged;

  static const _modes = [
    (value: 'cash',   label: 'Cash',    icon: Icons.money),
    (value: 'upi',    label: 'UPI',     icon: Icons.qr_code_2),
    (value: 'cheque', label: 'Cheque',  icon: Icons.description_outlined),
  ];

  @override
  Widget build(BuildContext context) => Row(
    children: _modes.map((m) {
      final isActive = m.value == selected;
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: m.value == _modes.last.value ? 0 : 8),
          child: GestureDetector(
            onTap: () => onChanged(m.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? OlColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? OlColors.primary : OlColors.border,
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(m.icon, color: isActive ? Colors.white : OlColors.textSecondary, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : OlColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}
