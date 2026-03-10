import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/success_overlay.dart';
import '../../retailers/repository/retailer_repository.dart';
import '../../../core/local_db/app_database.dart';
import '../providers/collection_provider.dart';

/// M5.1 — Standalone Quick Collect screen for sales reps.
/// Allows recording a payment for any customer, offline-first.
class QuickCollectScreen extends ConsumerStatefulWidget {
  /// Optional pre-selected customer (from collection schedule).
  final int?    prefilledCustomerId;
  final String? prefilledCustomerName;
  final double? prefilledAmount;
  final int?    collectionScheduleId;

  const QuickCollectScreen({
    super.key,
    this.prefilledCustomerId,
    this.prefilledCustomerName,
    this.prefilledAmount,
    this.collectionScheduleId,
  });

  @override
  ConsumerState<QuickCollectScreen> createState() => _QuickCollectScreenState();
}

class _QuickCollectScreenState extends ConsumerState<QuickCollectScreen> {
  // ── Form controllers ──────────────────────────────────────────────────────
  final _amountCtrl    = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl     = TextEditingController();
  final _searchCtrl    = TextEditingController();

  // ── Selected customer ─────────────────────────────────────────────────────
  int?    _customerId;
  String? _customerName;

  // ── Payment mode ──────────────────────────────────────────────────────────
  String _mode = 'cash';
  final _modes = const ['cash', 'upi', 'cheque', 'neft', 'rtgs'];

  // ── Customer search ───────────────────────────────────────────────────────
  List<Retailer> _searchResults = [];
  bool           _searching     = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledCustomerId != null) {
      _customerId   = widget.prefilledCustomerId;
      _customerName = widget.prefilledCustomerName;
    }
    if (widget.prefilledAmount != null) {
      _amountCtrl.text = widget.prefilledAmount!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchCustomers(String q) async {
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await ref.read(appDatabaseProvider).searchRetailers(q);
    if (mounted) setState(() { _searchResults = results; _searching = false; });
  }

  void _selectCustomer(Retailer r) {
    setState(() {
      _customerId   = r.id;
      _customerName = r.name;
      _searchCtrl.clear();
      _searchResults = [];
    });
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (_customerId == null) {
      _showSnack('Please select a customer.', error: true);
      return;
    }
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid amount.', error: true);
      return;
    }
    if (_mode != 'cash' && _referenceCtrl.text.trim().isEmpty) {
      _showSnack('Reference / UTR is required for $_mode.', error: true);
      return;
    }

    final today = DateTime.now().toIso8601String().substring(0, 10);
    await ref.read(quickCollectProvider.notifier).submit(
      customerId:           _customerId!,
      customerName:         _customerName!,
      amount:               amount,
      paymentMode:          _mode,
      reference:            _referenceCtrl.text.trim().isNotEmpty ? _referenceCtrl.text.trim() : null,
      notes:                _notesCtrl.text.trim().isNotEmpty     ? _notesCtrl.text.trim()     : null,
      receivedDate:         today,
      collectionScheduleId: widget.collectionScheduleId,
    );
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? OlColors.error : OlColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final collectState = ref.watch(quickCollectProvider);

    // On success, pop back
    ref.listen<QuickCollectState>(quickCollectProvider, (prev, next) {
      if (!next.loading && next.success) {
        final isOffline = next.error != null;
        showSuccessOverlay(
          context,
          title: isOffline ? 'Queued Offline' : 'Payment Recorded!',
          subtitle: isOffline
              ? 'Will sync when internet is restored.'
              : 'Collection for ${_customerName ?? 'customer'} saved.',
          displayDuration: const Duration(milliseconds: 1800),
          onDone: () { if (mounted) context.pop(); },
        );
      }
    });

    return Scaffold(
      backgroundColor: OlColors.background,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Quick Collect',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Customer picker ────────────────────────────────────────
            _sectionLabel('Customer'),
            if (_customerId != null) ...[
              _selectedCustomerCard(),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => setState(() { _customerId = null; _customerName = null; }),
                child: const Text('Change customer'),
              ),
            ] else ...[
              TextField(
                controller:  _searchCtrl,
                decoration:  _inputDecoration(
                  hint:   'Search by name or code…',
                  prefix: const Icon(Icons.search, color: OlColors.textSecondary, size: 18),
                ),
                onChanged: _searchCustomers,
              ),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_searchResults.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: OlColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    shrinkWrap:   true,
                    physics:      const NeverScrollableScrollPhysics(),
                    itemCount:    _searchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = _searchResults[i];
                      return ListTile(
                        dense:    true,
                        title:    Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(r.code ?? '', style: const TextStyle(fontSize: 12)),
                        trailing: r.outstanding > 0
                            ? Text(
                                CurrencyFormatter.formatCompact(r.outstanding),
                                style: const TextStyle(color: OlColors.warning, fontSize: 12),
                              )
                            : null,
                        onTap: () => _selectCustomer(r),
                      );
                    },
                  ),
                ),
            ],

            const SizedBox(height: 20),

            // ── Amount ─────────────────────────────────────────────────
            _sectionLabel('Amount (₹)'),
            TextField(
              controller:  _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration:   _inputDecoration(hint: '0.00'),
              style:        const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 20),

            // ── Payment Mode ───────────────────────────────────────────
            _sectionLabel('Payment Mode'),
            _modeSelector(),

            const SizedBox(height: 20),

            // ── Reference (conditional) ────────────────────────────────
            if (_mode != 'cash') ...[
              _sectionLabel(
                _mode == 'cheque' ? 'Cheque Number' : 'UTR / Transaction ID',
              ),
              TextField(
                controller:  _referenceCtrl,
                decoration: _inputDecoration(hint: 'Enter reference number'),
              ),
              const SizedBox(height: 20),
            ],

            // ── Notes ──────────────────────────────────────────────────
            _sectionLabel('Notes (optional)'),
            TextField(
              controller: _notesCtrl,
              maxLines:   2,
              decoration: _inputDecoration(hint: 'Any remarks…'),
            ),

            const SizedBox(height: 32),

            // ── Submit ─────────────────────────────────────────────────
            SizedBox(
              width:  double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: collectState.loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: OlColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: collectState.loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Record Payment',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _selectedCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OlColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OlColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.store_outlined, color: OlColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _customerName ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: OlColors.primary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _modes.map((m) {
        final selected = m == _mode;
        return GestureDetector(
          onTap: () => setState(() => _mode = m),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color:        selected ? OlColors.primary : OlColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? OlColors.primary : OlColors.border,
              ),
            ),
            child: Text(
              m.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : OlColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: OlColors.textSecondary,
          ),
        ),
      );

  InputDecoration _inputDecoration({required String hint, Widget? prefix}) =>
      InputDecoration(
        hintText:        hint,
        prefixIcon:      prefix,
        filled:          true,
        fillColor:       OlColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: OlColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: OlColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: OlColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}
