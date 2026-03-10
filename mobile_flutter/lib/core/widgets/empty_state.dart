import 'package:flutter/material.dart';
import '../theme/colors.dart';

// ── Empty state data classes ──────────────────────────────────────────────────

class EmptyStateAction {
  final String   label;
  final VoidCallback onPressed;
  const EmptyStateAction({required this.label, required this.onPressed});
}

// ── Reusable empty state widget ───────────────────────────────────────────────

/// Centred empty state illustration + text + optional CTA.
/// Used consistently across all list/data screens in the app.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconColor,
  });

  final IconData   icon;
  final String     title;
  final String?    subtitle;
  final EmptyStateAction? action;
  final Color?     iconColor;

  // ── Pre-built named constructors for each screen ──────────────────────────

  factory AppEmptyState.noRetailers({VoidCallback? onSync}) => AppEmptyState(
    icon: Icons.store_outlined,
    title: 'No retailers found',
    subtitle: 'Your retailer list is empty. Sync to download the latest data.',
    action: onSync != null ? EmptyStateAction(label: 'Sync Now', onPressed: onSync) : null,
  );

  factory AppEmptyState.noProducts() => const AppEmptyState(
    icon: Icons.inventory_2_outlined,
    title: 'No products in this category',
    subtitle: 'Try a different category or search by name or SKU.',
  );

  factory AppEmptyState.noOrders({VoidCallback? onCreate}) => AppEmptyState(
    icon: Icons.receipt_long_outlined,
    title: 'No orders yet',
    subtitle: 'Start by creating your first order.',
    action: onCreate != null ? EmptyStateAction(label: 'Create Order', onPressed: onCreate) : null,
  );

  factory AppEmptyState.noTrips() => const AppEmptyState(
    icon: Icons.local_shipping_outlined,
    title: 'No trips assigned',
    subtitle: 'Contact your manager to get a trip assigned.',
  );

  factory AppEmptyState.noCollections({VoidCallback? onSync}) => AppEmptyState(
    icon: Icons.calendar_today_outlined,
    title: 'No collections scheduled',
    subtitle: 'Pull down to sync for the latest schedule.',
    action: onSync != null ? EmptyStateAction(label: 'Sync Now', onPressed: onSync) : null,
  );

  factory AppEmptyState.allCaughtUp() => const AppEmptyState(
    icon: Icons.notifications_none_outlined,
    title: 'All caught up!',
    subtitle: "You're up to date — no new notifications.",
    iconColor: OlColors.success,
  );

  factory AppEmptyState.noBeatPlan() => const AppEmptyState(
    icon: Icons.map_outlined,
    title: 'No beat plan for today',
    subtitle: 'Contact your manager to assign a beat plan for today.',
  );

  factory AppEmptyState.everythingSynced() => const AppEmptyState(
    icon: Icons.cloud_done_outlined,
    title: 'Everything is in sync ✓',
    subtitle: 'All your data has been uploaded to the server.',
    iconColor: OlColors.success,
  );

  factory AppEmptyState.searchEmpty({required String query}) => AppEmptyState(
    icon: Icons.search_off_outlined,
    title: 'No results for "$query"',
    subtitle: 'Try a different search term.',
  );

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? OlColors.border;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular icon backdrop
            ExcludeSemantics(
              child: Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: effectiveIconColor),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: OlColors.textPrimary,
              ),
            ),

            // Subtitle
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: OlColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],

            // CTA button
            if (action != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: action!.onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: OlColors.primary,
                  minimumSize: const Size(160, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(action!.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
