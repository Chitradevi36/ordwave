import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../models/trip.dart';
import '../providers/trip_provider.dart';

class PartialDeliveryScreen extends ConsumerStatefulWidget {
  const PartialDeliveryScreen({super.key, required this.tripId, required this.stop});
  final int          tripId;
  final TripStopItem stop;

  @override
  ConsumerState<PartialDeliveryScreen> createState() => _PartialDeliveryScreenState();
}

class _PartialDeliveryScreenState extends ConsumerState<PartialDeliveryScreen> {
  // productId → delivered qty (edited by user)
  late final Map<int, TextEditingController> _deliveredCtrls;
  // productId → rejected qty
  late final Map<int, TextEditingController> _rejectedCtrls;
  // productId → reason code
  final Map<int, String> _reasonCodes = {};

  static const _reasons = ['damaged', 'refused', 'expired', 'short_qty'];

  @override
  void initState() {
    super.initState();
    _deliveredCtrls = {
      for (final l in widget.stop.lines)
        l.productId: TextEditingController(text: l.qtyOrdered.toStringAsFixed(0)),
    };
    _rejectedCtrls = {
      for (final l in widget.stop.lines)
        l.productId: TextEditingController(text: '0'),
    };
  }

  @override
  void dispose() {
    for (final c in _deliveredCtrls.values) { c.dispose(); }
    for (final c in _rejectedCtrls.values)  { c.dispose(); }
    super.dispose();
  }

  List<Map<String, dynamic>> _buildDeliveredLines() => widget.stop.lines.map((l) => {
    'sales_order_line_id': l.id,
    'product_id':          l.productId,
    'qty_delivered':       double.tryParse(_deliveredCtrls[l.productId]!.text) ?? 0.0,
  }).toList();

  List<Map<String, dynamic>> _buildRejections() {
    final list = <Map<String, dynamic>>[];
    for (final l in widget.stop.lines) {
      final qty = double.tryParse(_rejectedCtrls[l.productId]!.text) ?? 0.0;
      if (qty > 0) {
        list.add({
          'product_id':   l.productId,
          'qty_rejected': qty,
          'qty_returned': qty,
          'reason_code':  _reasonCodes[l.productId] ?? 'refused',
        });
      }
    }
    return list;
  }

  bool get _hasRejections => widget.stop.lines.any((l) {
    final qty = double.tryParse(_rejectedCtrls[l.productId]!.text) ?? 0.0;
    return qty > 0;
  });

  void _proceed() {
    final rejections = _buildRejections();
    final outcome    = _hasRejections ? 'partial_delivery' : 'delivered';
    context.go(
      '/home/trips/${widget.tripId}/stops/${widget.stop.id}/pod',
      extra: {
        'stop':            widget.stop,
        'tripId':          widget.tripId,
        'outcome':         outcome,
        'deliveredLines':  _buildDeliveredLines(),
        'rejections':      rejections,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OlColors.background,
      appBar: AppBar(
        backgroundColor: OlColors.warning,
        foregroundColor: Colors.white,
        title: const Text('Partial Delivery', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // ── Info banner ──
          Container(
            color: OlColors.warning.withOpacity(0.08),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: OlColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Edit delivered qty and flag any returns. Rejected items will raise a return request automatically.',
                    style: const TextStyle(fontSize: 13, color: OlColors.warning),
                  ),
                ),
              ],
            ),
          ),

          // ── Line editor ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: widget.stop.lines.map((l) => _LineEditor(
                line:         l,
                deliveredCtrl: _deliveredCtrls[l.productId]!,
                rejectedCtrl:  _rejectedCtrls[l.productId]!,
                reasonCode:    _reasonCodes[l.productId],
                reasons:       _reasons,
                onReasonChanged: (val) => setState(() => _reasonCodes[l.productId] = val),
              )).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: OlColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.navigate_next),
              label: const Text('Next: Confirm Delivery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              onPressed: _proceed,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Line Editor Row ──────────────────────────────────────────────────────────

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.line,
    required this.deliveredCtrl,
    required this.rejectedCtrl,
    required this.reasonCode,
    required this.reasons,
    required this.onReasonChanged,
  });

  final StopLine             line;
  final TextEditingController deliveredCtrl;
  final TextEditingController rejectedCtrl;
  final String?              reasonCode;
  final List<String>         reasons;
  final ValueChanged<String> onReasonChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: OlColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line.productName, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('Ordered: ${line.qtyOrdered} units  ·  ₹${line.unitPrice}',
                style: const TextStyle(fontSize: 12, color: OlColors.textSecondary)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QtyField(
                    controller: deliveredCtrl,
                    label: 'Delivered',
                    color: OlColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QtyField(
                    controller: rejectedCtrl,
                    label: 'Rejected',
                    color: OlColors.error,
                  ),
                ),
              ],
            ),
            // Show reason dropdown only when rejected qty > 0
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: rejectedCtrl,
              builder: (_, val, __) {
                final qty = double.tryParse(val.text) ?? 0;
                if (qty <= 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: DropdownButtonFormField<String>(
                    value: reasonCode ?? 'refused',
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: reasons.map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.replaceAll('_', ' ')),
                    )).toList(),
                    onChanged: (v) { if (v != null) onReasonChanged(v); },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyField extends StatelessWidget {
  const _QtyField({required this.controller, required this.label, required this.color});
  final TextEditingController controller;
  final String                label;
  final Color                 color;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.center,
    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: color),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: color),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
