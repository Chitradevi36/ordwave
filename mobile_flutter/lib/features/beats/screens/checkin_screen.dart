import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../providers/beat_provider.dart';

class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key, required this.retailer, this.onRefresh});

  final BeatRetailer retailer;
  final VoidCallback? onRefresh;

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  bool _loading = false;
  String? _error;

  // Outcome selection (checkout)
  String  _selectedOutcome = 'order_taken';
  String? _skipReason;
  final _skipReasonController = TextEditingController();

  static const List<Map<String, String>> _outcomes = [
    {'value': 'order_taken',     'label': 'Order Taken'},
    {'value': 'follow_up',       'label': 'Follow Up Required'},
    {'value': 'not_interested',  'label': 'Not Interested'},
    {'value': 'closed',          'label': 'Shop Closed'},
  ];

  static const List<String> _skipReasons = [
    'Shop closed',
    'No answer at door',
    'Customer requested skip',
    'Not on route today',
    'Other',
  ];

  @override
  void dispose() {
    _skipReasonController.dispose();
    super.dispose();
  }

  BeatService get _svc => ref.read(beatServiceProvider);

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _checkIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Use 0.0 / 0.0 as placeholder coords — GPS plugin would be added with geolocator
      await _svc.checkIn(widget.retailer.retailerId, 0.0, 0.0);
      widget.onRefresh?.call();
      if (mounted) setState(() => _loading = false);
      if (mounted) ref.invalidate(todayBeatProvider);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _checkOut() async {
    setState(() { _loading = true; _error = null; });
    try {
      final visitId = widget.retailer.visitId;
      if (visitId == null) throw Exception('No active visit found');
      await _svc.checkOut(visitId, 0.0, 0.0, _selectedOutcome);
      widget.onRefresh?.call();
      ref.invalidate(todayBeatProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _skip() async {
    final reason = _skipReasonController.text.trim().isNotEmpty
        ? _skipReasonController.text.trim()
        : _skipReason ?? 'No reason provided';

    setState(() { _loading = true; _error = null; });
    try {
      final visitId = widget.retailer.visitId;
      if (visitId == null) throw Exception('No active visit found');
      await _svc.skipVisit(visitId, reason);
      widget.onRefresh?.call();
      ref.invalidate(todayBeatProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = widget.retailer;
    final isCheckedIn = r.visitStatus == 'checked_in';
    final isDone      = r.visitStatus == 'checked_out' || r.visitStatus == 'skipped';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Check In / Out', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RetailerCard(retailer: r),
            const SizedBox(height: 20),

            if (_error != null)
              _ErrorBanner(message: _error!, onDismiss: () => setState(() => _error = null)),

            if (isDone)
              _VisitDoneBanner(status: r.visitStatus ?? 'done')
            else if (!isCheckedIn) ...[
              _SectionTitle('Check In'),
              const SizedBox(height: 8),
              Text(
                'Tap below to record your arrival at this retailer.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _checkIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.login),
                  label: Text(_loading ? 'Checking in…' : 'Check In', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ] else ...[
              // Check-out section
              _SectionTitle('Record Outcome'),
              const SizedBox(height: 8),
              ...(_outcomes.map((o) => RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: o['value']!,
                groupValue: _selectedOutcome,
                onChanged: (v) => setState(() => _selectedOutcome = v!),
                title: Text(o['label']!, style: const TextStyle(fontSize: 14)),
                activeColor: AppColors.accent,
              ))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _checkOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.logout),
                  label: Text(_loading ? 'Saving…' : 'Check Out', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),

              // Skip section
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              _SectionTitle('Skip This Visit'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _skipReason,
                hint: const Text('Select a reason'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _skipReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _skipReason = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _skipReasonController,
                decoration: InputDecoration(
                  hintText: 'Additional notes (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _skip,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Skip Visit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _RetailerCard extends StatelessWidget {
  const _RetailerCard({required this.retailer});
  final BeatRetailer retailer;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.accent.withOpacity(0.15),
              child: Text(
                retailer.retailerName.isNotEmpty ? retailer.retailerName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(retailer.retailerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (retailer.phone != null) ...[
                    const SizedBox(height: 2),
                    Text(retailer.phone!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                  if (retailer.address != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      retailer.address!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700));
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.danger))),
          GestureDetector(onTap: onDismiss, child: const Icon(Icons.close, size: 16, color: AppColors.danger)),
        ],
      ),
    );
  }
}

class _VisitDoneBanner extends StatelessWidget {
  const _VisitDoneBanner({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isSkipped = status == 'skipped';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isSkipped ? AppColors.textSecondary : AppColors.success).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isSkipped ? AppColors.textSecondary : AppColors.success).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isSkipped ? Icons.skip_next : Icons.check_circle,
            color: isSkipped ? AppColors.textSecondary : AppColors.success,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            isSkipped ? 'This visit was skipped.' : 'Visit completed.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isSkipped ? AppColors.textSecondary : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
