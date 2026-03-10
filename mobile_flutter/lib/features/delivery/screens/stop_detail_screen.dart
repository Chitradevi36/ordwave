import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';
import '../models/trip.dart';

class StopDetailScreen extends StatelessWidget {
  const StopDetailScreen({super.key, required this.tripId, required this.stop});
  final int          tripId;
  final TripStopItem stop;

  bool get _isTerminal =>
      stop.status == 'delivered' ||
      stop.status == 'partial_delivery' ||
      stop.status == 'failed' ||
      stop.status == 'skipped';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OlColors.background,
      appBar: AppBar(
        backgroundColor: OlColors.primary,
        foregroundColor: Colors.white,
        title: Text(stop.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (stop.phone != null)
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: () => launchUrl(Uri.parse('tel:${stop.phone}')),
              tooltip: 'Call customer',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Customer header card ──
          _CustomerCard(stop: stop),
          const SizedBox(height: 16),

          // ── Order lines ──
          const Text('ORDER LINES', style: _sectionLabelStyle),
          const SizedBox(height: 8),
          _OrderLinesCard(lines: stop.lines),
          const SizedBox(height: 24),

          // ── Action buttons (hidden when terminal) ──
          if (!_isTerminal) ...[
            const Text('ACTIONS', style: _sectionLabelStyle),
            const SizedBox(height: 8),
            _ActionButtons(tripId: tripId, stop: stop),
          ] else ...[
            // Show completion status
            _CompletionBanner(stop: stop),
          ],
        ],
      ),
    );
  }

  static const _sectionLabelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: OlColors.textSecondary,
    letterSpacing: 0.8,
  );
}

// ─── Customer Card ────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.stop});
  final TripStopItem stop;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: OlColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: OlColors.primary.withOpacity(0.1),
                child: const Icon(Icons.store, color: OlColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    if (stop.address != null)
                      Text(stop.address!,
                          style: const TextStyle(fontSize: 13, color: OlColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          if (stop.phone != null) ...[
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: OlColors.textSecondary),
                const SizedBox(width: 6),
                Text(stop.phone!, style: const TextStyle(color: OlColors.textSecondary)),
              ],
            ),
          ],
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 16, color: OlColors.textSecondary),
              const SizedBox(width: 6),
              Text('Order #${stop.salesOrderId}',
                  style: const TextStyle(color: OlColors.textSecondary)),
              const Spacer(),
              _StatusPill(status: stop.status),
            ],
          ),
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  Color get _color {
    switch (status) {
      case 'delivered':        return OlColors.success;
      case 'partial_delivery': return OlColors.warning;
      case 'failed':           return OlColors.error;
      default:                 return OlColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status.replaceAll('_', ' '),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _color),
    ),
  );
}

// ─── Order Lines Card ─────────────────────────────────────────────────────────

class _OrderLinesCard extends StatelessWidget {
  const _OrderLinesCard({required this.lines});
  final List<StopLine> lines;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: OlColors.border),
    ),
    child: lines.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No line items.', style: TextStyle(color: OlColors.textSecondary)),
          )
        : Column(
            children: lines.map((l) => _LineTile(line: l, isLast: l == lines.last)).toList(),
          ),
  );
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, required this.isLast});
  final StopLine line;
  final bool     isLast;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.productName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (line.sku != null)
                    Text('SKU: ${line.sku}',
                        style: const TextStyle(fontSize: 12, color: OlColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${line.qtyOrdered} units',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('₹${line.unitPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: OlColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
      if (!isLast) const Divider(height: 0, indent: 16, endIndent: 16),
    ],
  );
}

// ─── Action Buttons ───────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.tripId, required this.stop});
  final int          tripId;
  final TripStopItem stop;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.check_circle_outline,
          color: OlColors.success,
          title: 'Mark Delivered',
          subtitle: 'Full delivery of all items',
          onTap: () => context.go(
            '/home/trips/$tripId/stops/${stop.id}/pod',
            extra: {'stop': stop, 'tripId': tripId, 'outcome': 'delivered'},
          ),
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.tune,
          color: OlColors.warning,
          title: 'Partial Delivery',
          subtitle: 'Edit quantities / return items',
          onTap: () => context.go(
            '/home/trips/$tripId/stops/${stop.id}/partial',
            extra: {'stop': stop, 'tripId': tripId},
          ),
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.payments_outlined,
          color: OlColors.primary,
          title: 'Collect Payment',
          subtitle: 'Record cash, UPI or cheque',
          onTap: () => context.go(
            '/home/trips/$tripId/stops/${stop.id}/collect',
            extra: {'stop': stop, 'tripId': tripId},
          ),
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.cancel_outlined,
          color: OlColors.error,
          title: 'Mark Failed',
          subtitle: 'Customer not available / refused',
          onTap: () => context.go(
            '/home/trips/$tripId/stops/${stop.id}/pod',
            extra: {'stop': stop, 'tripId': tripId, 'outcome': 'failed'},
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData   icon;
  final Color      color;
  final String     title;
  final String     subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: color.withOpacity(0.3)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: OlColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    ),
  );
}

// ─── Completion Banner ────────────────────────────────────────────────────────

class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({required this.stop});
  final TripStopItem stop;

  @override
  Widget build(BuildContext context) {
    final isSuccess = stop.status == 'delivered' || stop.status == 'partial_delivery';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isSuccess ? OlColors.success : OlColors.error).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isSuccess ? OlColors.success : OlColors.error).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.cancel,
            color: isSuccess ? OlColors.success : OlColors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSuccess ? 'Stop Completed' : 'Stop Not Delivered',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isSuccess ? OlColors.success : OlColors.error,
                  ),
                ),
                if (stop.completedAt != null)
                  Text(
                    'At ${stop.completedAt}',
                    style: const TextStyle(fontSize: 12, color: OlColors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
