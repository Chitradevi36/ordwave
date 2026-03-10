import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/beat_provider.dart';

class BeatPlanScreen extends ConsumerStatefulWidget {
  const BeatPlanScreen({super.key});

  @override
  ConsumerState<BeatPlanScreen> createState() => _BeatPlanScreenState();
}

class _BeatPlanScreenState extends ConsumerState<BeatPlanScreen> {
  @override
  Widget build(BuildContext context) {
    final beatAsync = ref.watch(todayBeatProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Beat Plan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(todayBeatProvider),
          ),
        ],
      ),
      body: beatAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(todayBeatProvider)),
        data:    (beat) => beat == null ? AppEmptyState.noBeatPlan() : _BeatContent(beat: beat),
      ),
    );
  }
}

// ── Beat Content ──────────────────────────────────────────────────────────────

class _BeatContent extends ConsumerWidget {
  const _BeatContent({required this.beat});
  final TodayBeat beat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _SummaryHeader(beat: beat),
        Expanded(
          child: beat.retailers.isEmpty
              ? AppEmptyState.noBeatPlan()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: beat.retailers.length,
                  itemBuilder: (ctx, i) => _RetailerTile(
                    retailer: beat.retailers[i],
                    onRefresh: () => ref.invalidate(todayBeatProvider),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Summary header ─────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.beat});
  final TodayBeat beat;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${_weekday(now.weekday)}, ${now.day} ${_month(now.month)}';

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(beat.beatName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'Total',     value: '${beat.totalScheduled}', color: AppColors.textPrimary),
              const SizedBox(width: 16),
              _Stat(label: 'Done',      value: '${beat.completed}',      color: AppColors.success),
              const SizedBox(width: 16),
              _Stat(label: 'Active',    value: '${beat.checkedIn}',      color: AppColors.accent),
              const SizedBox(width: 16),
              _Stat(label: 'Skipped',   value: '${beat.skipped}',        color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: beat.totalScheduled > 0
                ? (beat.completed + beat.skipped) / beat.totalScheduled
                : 0,
            backgroundColor: AppColors.border,
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(4),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  String _weekday(int w) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
  String _month(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        Text(label,  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Retailer Tile ─────────────────────────────────────────────────────────────

class _RetailerTile extends StatelessWidget {
  const _RetailerTile({required this.retailer, required this.onRefresh});
  final BeatRetailer retailer;
  final VoidCallback  onRefresh;

  @override
  Widget build(BuildContext context) {
    final status = retailer.visitStatus;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'checked_out':
        statusColor = AppColors.success;
        statusLabel = 'Done';
        statusIcon  = Icons.check_circle_outline;
      case 'checked_in':
        statusColor = AppColors.accent;
        statusLabel = 'Active';
        statusIcon  = Icons.radio_button_checked;
      case 'skipped':
        statusColor = AppColors.textSecondary;
        statusLabel = 'Skipped';
        statusIcon  = Icons.skip_next_outlined;
      default:
        statusColor = AppColors.textSecondary;
        statusLabel = 'Pending';
        statusIcon  = Icons.circle_outlined;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/home/beat-checkin', extra: {
          'retailer': retailer,
          'onRefresh': onRefresh,
        }),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Sequence badge
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  retailer.sequence != null ? '#${retailer.sequence}' : '—',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
              const SizedBox(width: 12),

              // Name + address
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      retailer.retailerName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    if (retailer.address != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        retailer.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                    if (retailer.lastVisitDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Last visit: ${retailer.lastVisitDate!.substring(0, 10)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),

              // Status chip
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(statusIcon, color: statusColor, size: 18),
                  const SizedBox(height: 2),
                  Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Error views ──────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String   message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
