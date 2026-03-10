import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';
import '../models/trip.dart';
import '../providers/trip_provider.dart';

/// POD modes supported
enum PodMode { photo, otp, override }

class PodCaptureScreen extends ConsumerStatefulWidget {
  const PodCaptureScreen({
    super.key,
    required this.tripId,
    required this.stop,
    required this.outcome,
    this.deliveredLines = const [],
    this.rejections = const [],
  });

  final int                       tripId;
  final TripStopItem               stop;
  final String                    outcome;
  final List<Map<String, dynamic>> deliveredLines;
  final List<Map<String, dynamic>> rejections;

  @override
  ConsumerState<PodCaptureScreen> createState() => _PodCaptureScreenState();
}

class _PodCaptureScreenState extends ConsumerState<PodCaptureScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _otpCtrl      = TextEditingController();
  final _overrideCtrl = TextEditingController();
  File?  _photo;
  bool   _submitted = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: PodMode.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _otpCtrl.dispose();
    _overrideCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (xfile != null) setState(() => _photo = File(xfile.path));
  }

  Map<String, dynamic>? _buildProof() {
    switch (PodMode.values[_tabs.index]) {
      case PodMode.photo:
        if (_photo == null) return null;
        final bytes = _photo!.readAsBytesSync();
        return {'type': 'photo', 'data': base64Encode(bytes)};
      case PodMode.otp:
        final code = _otpCtrl.text.trim();
        if (code.isEmpty) return null;
        return {'type': 'otp', 'data': code};
      case PodMode.override:
        final reason = _overrideCtrl.text.trim();
        if (reason.isEmpty) return null;
        return {'type': 'override', 'data': reason};
    }
  }

  Future<void> _submit() async {
    final proof = _buildProof();
    if (proof == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide proof of delivery.')),
      );
      return;
    }
    setState(() => _submitted = true);

    final notifier = ref.read(completeStopProvider.notifier);
    final ok = await notifier.completeStop(
      tripId:         widget.tripId,
      stopId:         widget.stop.id,
      outcome:        widget.outcome,
      deliveredLines: widget.deliveredLines.isEmpty
          ? _defaultDeliveredLines()
          : widget.deliveredLines,
      rejections:     widget.rejections,
      proof:          proof,
      completedAt:    DateTime.now().toIso8601String(),
    );

    if (!mounted) return;
    setState(() => _submitted = false);

    if (ok) {
      ref.invalidate(tripDetailProvider(widget.tripId));
      context.go('/home/trips/${widget.tripId}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stop marked as ${widget.outcome.replaceAll('_', ' ')}!'),
          backgroundColor: OlColors.success,
        ),
      );
    } else {
      final err = ref.read(completeStopProvider).error ?? 'Unknown error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $err'), backgroundColor: OlColors.error),
      );
      ref.read(completeStopProvider.notifier).clearError();
    }
  }

  List<Map<String, dynamic>> _defaultDeliveredLines() => widget.stop.lines.map((l) => {
    'sales_order_line_id': l.id,
    'product_id':          l.productId,
    'qty_delivered':       l.qtyOrdered,
  }).toList();

  Color get _outcomeColor {
    if (widget.outcome == 'delivered')        return OlColors.success;
    if (widget.outcome == 'partial_delivery') return OlColors.warning;
    return OlColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(completeStopProvider);

    return Scaffold(
      backgroundColor: OlColors.background,
      appBar: AppBar(
        backgroundColor: _outcomeColor,
        foregroundColor: Colors.white,
        title: const Text('Proof of Delivery', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.camera_alt_outlined), text: 'Photo'),
            Tab(icon: Icon(Icons.pin_outlined),        text: 'OTP'),
            Tab(icon: Icon(Icons.edit_note_outlined),  text: 'Override'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Outcome badge ──
          Container(
            color: _outcomeColor.withOpacity(0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: _outcomeColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recording outcome: ${widget.outcome.replaceAll("_", " ")}  ·  ${widget.stop.customerName}',
                    style: TextStyle(fontSize: 13, color: _outcomeColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // ── Photo tab ──
                _PhotoTab(photo: _photo, onPickPhoto: _pickPhoto),
                // ── OTP tab ──
                _OtpTab(controller: _otpCtrl),
                // ── Override / waiver tab ──
                _OverrideTab(controller: _overrideCtrl),
              ],
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
                backgroundColor: _outcomeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: state.loading || _submitted
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(
                state.loading || _submitted ? 'Submitting…' : 'Confirm & Submit',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              onPressed: state.loading || _submitted ? null : _submit,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Photo Tab ────────────────────────────────────────────────────────────────

class _PhotoTab extends StatelessWidget {
  const _PhotoTab({required this.photo, required this.onPickPhoto});
  final File?      photo;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (photo != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(photo!, height: 240, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onPickPhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Retake Photo'),
          ),
        ] else ...[
          Icon(Icons.camera_alt_outlined, size: 72, color: OlColors.textDisabled),
          const SizedBox(height: 16),
          const Text(
            'Take a photo as proof of delivery',
            textAlign: TextAlign.center,
            style: TextStyle(color: OlColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: OlColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Open Camera'),
            onPressed: onPickPhoto,
          ),
        ],
      ],
    ),
  );
}

// ─── OTP Tab ──────────────────────────────────────────────────────────────────

class _OtpTab extends StatelessWidget {
  const _OtpTab({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, size: 56, color: OlColors.primary),
        const SizedBox(height: 16),
        const Text(
          'Enter the OTP shared by the customer',
          textAlign: TextAlign.center,
          style: TextStyle(color: OlColors.textSecondary),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 8,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 8),
          decoration: const InputDecoration(
            hintText: '------',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
      ],
    ),
  );
}

// ─── Override Tab ─────────────────────────────────────────────────────────────

class _OverrideTab extends StatelessWidget {
  const _OverrideTab({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.edit_note, size: 48, color: OlColors.textSecondary),
        const SizedBox(height: 12),
        const Text(
          'Manager override — provide reason for waiving POD',
          textAlign: TextAlign.center,
          style: TextStyle(color: OlColors.textSecondary),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Override reason *',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ),
  );
}
