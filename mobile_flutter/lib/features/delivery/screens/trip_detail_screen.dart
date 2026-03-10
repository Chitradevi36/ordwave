import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../models/trip.dart';
import '../providers/trip_provider.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});
  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripDetailProvider(tripId));

    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Trip Detail')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (trip) => _TripDetailView(trip: trip),
    );
  }
}

class _TripDetailView extends ConsumerWidget {
  const _TripDetailView({required this.trip});
  final DeliveryTrip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stops   = trip.stops;
    final pending = stops.where((s) => s.status == 'pending').length;
    final done    = stops.length - pending;

    return Scaffold(
      backgroundColor: OlColors.background,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: Text(trip.tripNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(tripDetailProvider(trip.id)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Trip progress header ──
          _TripProgressHeader(trip: trip, done: done),

          // ── Stop list ──
          Expanded(
            child: stops.isEmpty
                ? const Center(child: Text('No stops on this trip.'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: stops.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _StopTile(
                      stop: stops[i],
                      tripId: trip.id,
                      isActive: stops[i].status == 'pending' && (i == 0 || stops[i - 1].status != 'pending'),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: trip.status == 'dispatched' && pending == 0
          ? _CompleteBar(tripId: trip.id)
          : null,
    );
  }
}

// ─── Trip Progress Header ─────────────────────────────────────────────────────

class _TripProgressHeader extends StatelessWidget {
  const _TripProgressHeader({required this.trip, required this.done});
  final DeliveryTrip trip;
  final int done;

  @override
  Widget build(BuildContext context) {
    final total = trip.stops.length;
    final pct   = total == 0 ? 0.0 : done / total;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$done / $total stops completed',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      trip.vehicleNumber != null ? 'Vehicle: ${trip.vehicleNumber}' : trip.status,
                      style: const TextStyle(fontSize: 13, color: OlColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                '${(pct * 100).round()}%',
                style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: OlColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: OlColors.border,
              valueColor: AlwaysStoppedAnimation(
                pct >= 1.0 ? OlColors.success : OlColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Status breakdown chips
          _StatusBreakdown(stops: trip.stops),
        ],
      ),
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.stops});
  final List<TripStopItem> stops;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final s in stops) {
      counts[s.status] = (counts[s.status] ?? 0) + 1;
    }
    final chips = <Widget>[];
    void add(String key, String label, Color color) {
      if ((counts[key] ?? 0) > 0) {
        chips.add(_Chip(label: '${counts[key]} $label', color: color));
      }
    }
    add('pending',          'Pending',  OlColors.textSecondary);
    add('delivered',        'Done',     OlColors.success);
    add('partial_delivery', 'Partial',  OlColors.warning);
    add('failed',           'Failed',   OlColors.error);
    add('skipped',          'Skipped',  OlColors.textDisabled);

    return Row(children: chips.map((c) => Padding(padding: const EdgeInsets.only(right: 6), child: c)).toList());
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color  color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );
}

// ─── Stop Tile ────────────────────────────────────────────────────────────────

class _StopTile extends StatelessWidget {
  const _StopTile({required this.stop, required this.tripId, required this.isActive});
  final TripStopItem stop;
  final int          tripId;
  final bool         isActive;

  Color get _color {
    switch (stop.status) {
      case 'delivered':        return OlColors.success;
      case 'partial_delivery': return OlColors.warning;
      case 'failed':           return OlColors.error;
      case 'skipped':          return OlColors.textDisabled;
      default:                 return isActive ? OlColors.primary : OlColors.textSecondary;
    }
  }

  IconData get _icon {
    switch (stop.status) {
      case 'delivered':        return Icons.check_circle;
      case 'partial_delivery': return Icons.warning_rounded;
      case 'failed':           return Icons.cancel;
      case 'skipped':          return Icons.skip_next;
      default:                 return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: isActive ? OlColors.primary : OlColors.border,
        width: isActive ? 1.5 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.go('/home/trips/$tripId/stops/${stop.id}',
          extra: {'stop': stop, 'tripId': tripId}),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Sequence badge
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: _color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${stop.sequence}',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stop.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (stop.address != null)
                    Text(stop.address!, style: const TextStyle(fontSize: 12, color: OlColors.textSecondary)),
                  if (stop.exceptionCode != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _Chip(label: stop.exceptionCode!, color: OlColors.error),
                    ),
                ],
              ),
            ),
            Icon(_icon, color: _color, size: 22),
          ],
        ),
      ),
    ),
  );
}

// ─── Complete Bar ─────────────────────────────────────────────────────────────

class _CompleteBar extends ConsumerWidget {
  const _CompleteBar({required this.tripId});
  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: OlColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Complete Trip', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            onPressed: () async {
              final dio = ref.read(apiClientProvider);
              try {
                await dio.post('/api/v1/delivery_trips/$tripId/complete');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Trip completed!'),
                      backgroundColor: OlColors.success,
                    ),
                  );
                  ref.invalidate(tripDetailProvider(tripId));
                  ref.invalidate(tripListProvider('today'));
                  ref.invalidate(tripListProvider('all'));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: OlColors.error),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }
}
