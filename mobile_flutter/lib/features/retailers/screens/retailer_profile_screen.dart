import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/theme/colors.dart';
import '../repository/retailer_repository.dart';

// ─── Providers ─────────────────────────────────────────────────────────────────

final _retailerDetailProvider = FutureProvider.autoDispose.family<Retailer?, int>((ref, id) async {
  final repo = ref.watch(retailerRepositoryProvider);
  return repo.getRetailer(id);
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class RetailerProfileScreen extends ConsumerWidget {
  const RetailerProfileScreen({required this.retailerId, super.key});
  final int retailerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_retailerDetailProvider(retailerId));

    return Scaffold(
      backgroundColor: OlColors.backgroundSubtle,
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (r) {
          if (r == null) {
            return const Center(
              child: Text('Retailer not found.', style: TextStyle(color: OlColors.textSecondary)),
            );
          }
          return _RetailerProfile(retailer: r);
        },
      ),
    );
  }
}

// ─── Main Profile Widget ───────────────────────────────────────────────────────

class _RetailerProfile extends ConsumerWidget {
  const _RetailerProfile({required this.retailer});
  final Retailer retailer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditStatus = retailer.creditStatus ?? 'ok';
    final outstanding  = retailer.outstanding;
    final creditLimit  = retailer.creditLimit;
    final isBlocked    = creditStatus == 'blocked' || retailer.status == 'blocked';

    return CustomScrollView(
      slivers: [
        // ── App Bar with header card ─────────────────────────────────────
        SliverAppBar(
          pinned: true,
          expandedHeight: 140,
          backgroundColor: OlColors.primary,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: _HeaderCard(retailer: retailer, creditStatus: creditStatus),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Credit Banner ────────────────────────────────────────
                _CreditBanner(
                  outstanding:  outstanding,
                  creditLimit:   creditLimit,
                  creditStatus:  creditStatus,
                  isBlocked:     isBlocked,
                ),
                const SizedBox(height: 16),

                // ── 2×2 Quick Info Grid ──────────────────────────────────
                _QuickInfoGrid(retailer: retailer),
                const SizedBox(height: 16),

                // ── Contact & Address ────────────────────────────────────
                if (retailer.phone != null || retailer.gstin != null)
                  _InfoCard(
                    title: 'Contact',
                    children: [
                      if (retailer.phone != null)
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: retailer.phone!,
                          onTap: () {}, // url_launcher can open tel: links
                        ),
                      if (retailer.gstin != null)
                        _InfoRow(icon: Icons.receipt_long_outlined, label: 'GSTIN', value: retailer.gstin!),
                    ],
                  ),
                if (retailer.address != null) ...[
                  const SizedBox(height: 12),
                  _InfoCard(
                    title: 'Address',
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(retailer.address!, style: const TextStyle(fontSize: 13, color: OlColors.textPrimary)),
                      ),
                    ],
                  ),
                ],
                // Space for bottom bar
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Header Card ──────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.retailer, required this.creditStatus});
  final Retailer retailer;
  final String   creditStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OlColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withOpacity(0.1),
            child: Text(
              retailer.name.isNotEmpty ? retailer.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(retailer.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    if (retailer.code != null)
                      _HeaderBadge(text: retailer.code!),
                    if (retailer.channel != null)
                      _HeaderBadge(text: retailer.channel!.replaceAll('_', ' ').toUpperCase()),
                    if (retailer.tier != null)
                      _HeaderBadge(text: retailer.tier!),
                    _CreditStatusPill(status: creditStatus),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
  );
}

class _CreditStatusPill extends StatelessWidget {
  const _CreditStatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'blocked'    => ('BLOCKED',    OlColors.error),
      'hold'       => ('ON HOLD',    OlColors.warning),
      'overdue'    => ('OVERDUE',    OlColors.error),
      'near_limit' => ('NEAR LIMIT', OlColors.warning),
      _            => ('OK',         OlColors.success),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color == OlColors.success ? OlColors.success : color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── Credit Banner ────────────────────────────────────────────────────────────

class _CreditBanner extends StatelessWidget {
  const _CreditBanner({
    required this.outstanding,
    required this.creditLimit,
    required this.creditStatus,
    required this.isBlocked,
  });
  final double outstanding;
  final double creditLimit;
  final String creditStatus;
  final bool   isBlocked;

  Color get _bannerColor => switch (creditStatus) {
    'blocked'    => OlColors.error50,
    'hold'       => OlColors.warning50,
    'overdue'    => OlColors.error50,
    'near_limit' => OlColors.warning50,
    _            => OlColors.success50,
  };
  Color get _borderColor => switch (creditStatus) {
    'blocked' || 'overdue' => OlColors.error,
    'hold'    || 'near_limit' => OlColors.warning,
    _ => OlColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final used   = creditLimit > 0 ? (outstanding / creditLimit).clamp(0.0, 1.0) : 0.0;
    final avail  = (creditLimit - outstanding).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bannerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Outstanding', style: TextStyle(fontSize: 11, color: OlColors.textSecondary)),
                    Text('₹${_fmt(outstanding)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: OlColors.textPrimary)),
                  ],
                ),
              ),
              if (creditLimit > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Available Credit', style: TextStyle(fontSize: 11, color: OlColors.textSecondary)),
                    Text('₹${_fmt(avail)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: avail <= 0 ? OlColors.error : OlColors.textPrimary)),
                  ],
                ),
            ],
          ),
          if (creditLimit > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: used,
                minHeight: 6,
                backgroundColor: _borderColor.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(_borderColor),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(used * 100).toStringAsFixed(0)}% utilised', style: const TextStyle(fontSize: 10, color: OlColors.textSecondary)),
                Text('Limit ₹${_fmt(creditLimit)}', style: const TextStyle(fontSize: 10, color: OlColors.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ─── 2×2 Quick Info Grid ──────────────────────────────────────────────────────

class _QuickInfoGrid extends StatelessWidget {
  const _QuickInfoGrid({required this.retailer});
  final Retailer retailer;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _QuickInfoTile(label: 'Last Order',   icon: Icons.shopping_cart_outlined,  value: _fmtDate(retailer.lastOrderDate)),
        _QuickInfoTile(label: 'Last Payment', icon: Icons.payments_outlined,        value: _fmtDate(retailer.lastPaymentDate)),
        _QuickInfoTile(label: 'Last Visit',   icon: Icons.location_on_outlined,    value: _fmtDate(retailer.lastVisitDate)),
        _QuickInfoTile(label: 'Status',       icon: Icons.verified_outlined,       value: retailer.status.toUpperCase()),
      ],
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day.toString().padLeft(2, '0')} ${_months[dt.month - 1]} ${dt.year}';
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
}

class _QuickInfoTile extends StatelessWidget {
  const _QuickInfoTile({required this.label, required this.icon, required this.value});
  final String   label;
  final IconData icon;
  final String   value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OlColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: OlColors.primary300),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: OlColors.textSecondary)),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: OlColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OlColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: OlColors.textSecondary)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.onTap});
  final IconData icon;
  final String   label;
  final String   value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 16, color: OlColors.primary300),
            const SizedBox(width: 8),
            Text('$label: ', style: const TextStyle(fontSize: 12, color: OlColors.textSecondary)),
            Expanded(
              child: Text(
                value,
                style: TextStyle(fontSize: 12, color: onTap != null ? OlColors.info : OlColors.textPrimary, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
