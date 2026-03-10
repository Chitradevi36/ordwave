import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';
import '../models/trip.dart';

/// Standalone returns-at-delivery flow.  Can be reached from the stop detail
/// "Return Items" action (independent of partial delivery flow).
class ReturnsAtDeliveryScreen extends ConsumerStatefulWidget {
  const ReturnsAtDeliveryScreen({super.key, required this.tripId, required this.stop});
  final int          tripId;
  final TripStopItem stop;

  @override
  ConsumerState<ReturnsAtDeliveryScreen> createState() =>
      _ReturnsAtDeliveryScreenState();
}

class _ReturnsAtDeliveryScreenState extends ConsumerState<ReturnsAtDeliveryScreen> {
  // productId → {qty, reason, condition, photo}
  final Map<int, _ReturnEntry> _entries = {};

  static const _reasons    = ['damaged', 'refused', 'expired', 'short_qty'];
  static const _conditions = ['good', 'damaged', 'unsaleable'];

  @override
  void initState() {
    super.initState();
    for (final l in widget.stop.lines) {
      _entries[l.productId] = _ReturnEntry(
        productId:   l.productId,
        productName: l.productName,
        maxQty:      l.qtyOrdered,
      );
    }
  }

  Future<void> _pickPhoto(int productId) async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
    if (xfile != null) {
      setState(() => _entries[productId]?.photoPath = xfile.path);
    }
  }

  List<Map<String, dynamic>> _buildPayload() {
    return _entries.values
        .where((e) => e.qty > 0)
        .map((e) => {
              'product_id':   e.productId,
              'qty_rejected': e.qty,
              'qty_returned': e.qty,
              'reason_code':  e.reason ?? 'refused',
              'condition':    e.condition ?? 'good',
            })
        .toList();
  }

  bool get _hasItems => _entries.values.any((e) => e.qty > 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OlColors.background,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Returns at Delivery', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OlColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OlColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: OlColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Add items being returned by ${widget.stop.customerName}.',
                    style: const TextStyle(color: OlColors.warning, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._entries.values.map((entry) => _ReturnItemCard(
                entry:        entry,
                reasons:      _reasons,
                conditions:   _conditions,
                onChanged:    () => setState(() {}),
                onPickPhoto:  () => _pickPhoto(entry.productId),
              )),
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
                backgroundColor: _hasItems ? OlColors.primary : OlColors.textDisabled,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Proceed to POD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              onPressed: _hasItems
                  ? () {
                      final rejections = _buildPayload();
                      context.go(
                        '/home/trips/${widget.tripId}/stops/${widget.stop.id}/pod',
                        extra: {
                          'stop':           widget.stop,
                          'tripId':         widget.tripId,
                          'outcome':        'partial_delivery',
                          'deliveredLines': <Map<String, dynamic>>[],
                          'rejections':     rejections,
                        },
                      );
                    }
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Entry model ─────────────────────────────────────────────────────────────

class _ReturnEntry {
  _ReturnEntry({required this.productId, required this.productName, required this.maxQty});
  final int    productId;
  final String productName;
  final double maxQty;
  double  qty       = 0;
  String? reason;
  String? condition;
  String? photoPath;
}

// ─── Return item card ─────────────────────────────────────────────────────────

class _ReturnItemCard extends StatelessWidget {
  const _ReturnItemCard({
    required this.entry,
    required this.reasons,
    required this.conditions,
    required this.onChanged,
    required this.onPickPhoto,
  });
  final _ReturnEntry       entry;
  final List<String>       reasons;
  final List<String>       conditions;
  final VoidCallback       onChanged;
  final VoidCallback       onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: entry.qty > 0 ? OlColors.error.withOpacity(0.4) : OlColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.productName, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('Max returnable: ${entry.maxQty.toStringAsFixed(0)} units',
                style: const TextStyle(fontSize: 12, color: OlColors.textSecondary)),
            const SizedBox(height: 12),
            // Qty Row
            Row(
              children: [
                const Text('Return qty: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: OlColors.error),
                  onPressed: () {
                    if (entry.qty > 0) { entry.qty -= 1; onChanged(); }
                  },
                ),
                Text(entry.qty.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: OlColors.success),
                  onPressed: () {
                    if (entry.qty < entry.maxQty) { entry.qty += 1; onChanged(); }
                  },
                ),
              ],
            ),
            if (entry.qty > 0) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: entry.reason ?? 'refused',
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                items: reasons.map((r) => DropdownMenuItem(
                  value: r, child: Text(r.replaceAll('_', ' ')),
                )).toList(),
                onChanged: (v) { entry.reason = v; onChanged(); },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: entry.condition ?? 'good',
                decoration: const InputDecoration(
                  labelText: 'Condition',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                items: conditions.map((c) => DropdownMenuItem(
                  value: c, child: Text(c),
                )).toList(),
                onChanged: (v) { entry.condition = v; onChanged(); },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(entry.photoPath != null ? 'Retake Photo' : 'Add Photo (optional)'),
                onPressed: onPickPhoto,
              ),
              if (entry.photoPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(entry.photoPath!),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
