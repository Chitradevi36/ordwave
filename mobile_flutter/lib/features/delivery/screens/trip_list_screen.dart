import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/trip.dart';
import '../providers/trip_provider.dart';

class TripListScreen extends ConsumerStatefulWidget {
  const TripListScreen({super.key});

  @override
  ConsumerState<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends ConsumerState<TripListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OlColors.background,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: const Text('My Trips', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: "Today"),
            Tab(text: "All"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _TripList(filter: 'today'),
          _TripList(filter: 'all'),
        ],
      ),
    );
  }
}

// ─── Trip list for a given filter ────────────────────────────────────────────

class _TripList extends ConsumerWidget {
  const _TripList({required this.filter});
  final String filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripListProvider(filter));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: OlColors.textDisabled),
            const SizedBox(height: 12),
            Text('Could not load trips', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(tripListProvider(filter)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (trips) {
        if (trips.isEmpty) {
          return const AppEmptyState(
            icon: Icons.local_shipping_outlined,
            title: 'No trips found',
            subtitle: 'Trips assigned to you will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(tripListProvider(filter)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) => _TripCard(trip: trips[i]),
          ),
        );
      },
    );
  }
}

// ─── Trip Card ────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final DeliveryTrip trip;

  Color get _statusColor {
    switch (trip.status) {
      case 'dispatched': return OlColors.primary;
      case 'completed':  return OlColors.success;
      case 'cancelled':  return OlColors.error;
      default:           return OlColors.textSecondary;
    }
  }

  String get _statusLabel {
    switch (trip.status) {
      case 'planned':    return 'Planned';
      case 'dispatched': return 'In Progress';
      case 'completed':  return 'Completed';
      case 'cancelled':  return 'Cancelled';
      default:           return trip.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalStops     = trip.stops.length;
    final completedStops = trip.stops.where((s) =>
        s.status == 'delivered' ||
        s.status == 'partial_delivery' ||
        s.status == 'failed' ||
        s.status == 'skipped').length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OlColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/home/trips/${trip.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.tripNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Meta row
              Wrap(
                spacing: 16,
                children: [
                  if (trip.vehicleNumber != null)
                    _MetaChip(icon: Icons.directions_car_outlined, label: trip.vehicleNumber!),
                  if (trip.branchName != null)
                    _MetaChip(icon: Icons.warehouse_outlined, label: trip.branchName!),
                  if (trip.scheduledDate != null)
                    _MetaChip(icon: Icons.calendar_today_outlined, label: trip.scheduledDate!),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar
              if (totalStops > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$completedStops / $totalStops stops',
                      style: const TextStyle(fontSize: 13, color: OlColors.textSecondary),
                    ),
                    Text(
                      '${(completedStops / totalStops * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: OlColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completedStops / totalStops,
                    backgroundColor: OlColors.border,
                    valueColor: AlwaysStoppedAnimation(
                      totalStops == completedStops ? OlColors.success : OlColors.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: OlColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: OlColors.textSecondary)),
        ],
      );
}
