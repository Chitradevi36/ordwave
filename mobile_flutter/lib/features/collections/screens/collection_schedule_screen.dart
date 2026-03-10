import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/formatters.dart';
import '../providers/collection_provider.dart';

/// M5.2 — Collection schedule screen for sales reps.
/// Tabs: Today / This Week / Overdue.
/// Each card: customer, amount expected, status.
/// Actions: Collect (→ QuickCollect) • Skip (inline reason dialog).
class CollectionScheduleScreen extends ConsumerStatefulWidget {
  const CollectionScheduleScreen({super.key});

  @override
  ConsumerState<CollectionScheduleScreen> createState() =>
      _CollectionScheduleScreenState();
}

class _CollectionScheduleScreenState
    extends ConsumerState<CollectionScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  static const _tabDefs = [
    _TabDef(label: 'Today',    mode: 'today'),
    _TabDef(label: 'This Week',mode: 'week'),
    _TabDef(label: 'Overdue',  mode: 'overdue'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabDefs.length, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _reload();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    final mode = _tabDefs[_tabs.index].mode;
    final today = DateTime.now();
    final notifier = ref.read(collectionSchedulesProvider.notifier);

    switch (mode) {
      case 'today':
        notifier.fetch(date: _fmt(today));
      case 'week':
        final weekEnd = today.add(const Duration(days: 6));
        notifier.fetch(dateFrom: _fmt(today), dateTo: _fmt(weekEnd));
      case 'overdue':
        final yesterday = today.subtract(const Duration(days: 1));
        notifier.fetch(
            dateTo: _fmt(yesterday), status: 'planned');
    }
  }

  String _fmt(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionSchedulesProvider);

    return Scaffold(
      backgroundColor: OlColors.background,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Collection Schedule',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor:     Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: _tabDefs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: TabBarView(
          controller: _tabs,
          children: _tabDefs.map((_) => _ScheduleList(state: state)).toList(),
        ),
      ),
    );
  }
}

// ── Schedule list ──────────────────────────────────────────────────────────────

class _ScheduleList extends ConsumerWidget {
  final CollectionSchedulesState state;
  const _ScheduleList({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.schedules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: OlColors.textSecondary),
          ),
        ),
      );
    }

    if (state.schedules.isEmpty) {
      return AppEmptyState.noCollections();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.schedules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _ScheduleCard(schedule: state.schedules[i]),
    );
  }
}

// ── Schedule card ──────────────────────────────────────────────────────────────

class _ScheduleCard extends ConsumerWidget {
  final CollectionSchedule schedule;
  const _ScheduleCard({required this.schedule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverdue  = schedule.isOverdue;
    final borderColor = isOverdue ? OlColors.error : OlColors.border;
    final badgeColor  = _badgeColor(schedule.status);
    final badgeLabel  = schedule.status.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color:        OlColors.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color:  Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.store_outlined, size: 16, color: OlColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    schedule.customerName ?? 'Customer',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: OlColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      color:      badgeColor,
                      fontSize:   10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Amount + Date ──────────────────────────────────────────
            Row(
              children: [
                _meta(Icons.currency_rupee,
                    CurrencyFormatter.format(schedule.amountExpected)),
                const SizedBox(width: 16),
                _meta(
                  isOverdue ? Icons.warning_amber_rounded : Icons.calendar_today_outlined,
                  schedule.scheduledDate,
                  color: isOverdue ? OlColors.error : OlColors.textSecondary,
                ),
              ],
            ),

            if (schedule.assignedToName != null) ...[
              const SizedBox(height: 4),
              _meta(Icons.person_outline, schedule.assignedToName!),
            ],

            if (schedule.notes != null && schedule.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              _meta(Icons.notes, schedule.notes!),
            ],

            // ── Actions ───────────────────────────────────────────────
            if (schedule.status == 'planned') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Skip
                  OutlinedButton(
                    onPressed: () => _showSkipDialog(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OlColors.textSecondary,
                      side: const BorderSide(color: OlColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Skip', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  // Collect
                  ElevatedButton(
                    onPressed: () => context.push(
                      '/home/collect',
                      extra: {
                        'customerId':           schedule.customerId,
                        'customerName':         schedule.customerName,
                        'amount':               schedule.amountExpected,
                        'collectionScheduleId': schedule.id,
                      },
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OlColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Collect', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text, {Color? color}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color ?? OlColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color ?? OlColors.textSecondary,
            ),
          ),
        ],
      );

  Color _badgeColor(String status) {
    switch (status) {
      case 'completed':  return OlColors.success;
      case 'partial':    return OlColors.info;
      case 'skipped':    return OlColors.textSecondary;
      case 'rescheduled':return OlColors.warning;
      default:           return OlColors.primary;
    }
  }

  void _showSkipDialog(BuildContext context, WidgetRef ref) {
    final reasonCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip Schedule'),
        content: TextField(
          controller: reasonCtrl,
          maxLines:   2,
          decoration: const InputDecoration(
            hintText: 'Reason for skipping…',
            border:   OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              ctx.pop();
              final ok = await ref.read(collectionSchedulesProvider.notifier)
                  .skip(schedule.id, reason);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Schedule skipped.' : 'Failed to skip.'),
                  backgroundColor: ok ? OlColors.success : OlColors.error,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: OlColors.error),
            child: const Text('Skip', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _TabDef {
  final String label;
  final String mode;
  const _TabDef({required this.label, required this.mode});
}
