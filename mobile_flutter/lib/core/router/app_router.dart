import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../storage/secure_storage.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_shell.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/retailers/screens/retailer_list_screen.dart';
import '../../features/retailers/screens/retailer_profile_screen.dart';
import '../../features/orders/screens/order_list_screen.dart';
import '../../features/orders/screens/select_retailer_screen.dart';
import '../../features/orders/screens/product_picker_screen.dart';
import '../../features/orders/screens/cart_review_screen.dart';
import '../../features/orders/screens/credit_check_result_screen.dart';
import '../../features/orders/models/cart.dart';
import '../../features/delivery/screens/trip_list_screen.dart';
import '../../features/delivery/screens/trip_detail_screen.dart';
import '../../features/delivery/screens/stop_detail_screen.dart';
import '../../features/delivery/screens/partial_delivery_screen.dart';
import '../../features/delivery/screens/pod_capture_screen.dart';
import '../../features/delivery/screens/returns_at_delivery_screen.dart';
import '../../features/delivery/screens/cash_collection_screen.dart';
import '../../features/delivery/models/trip.dart';
import '../../features/collections/screens/quick_collect_screen.dart';
import '../../features/collections/screens/collection_schedule_screen.dart';
import '../../features/collections/screens/recent_collections_screen.dart';
import '../../features/beats/screens/beat_plan_screen.dart';
import '../../features/beats/screens/checkin_screen.dart';
import '../../features/beats/providers/beat_provider.dart';
import '../../features/notifications/screens/notification_inbox_screen.dart';
import '../../features/sync/screens/sync_center_screen.dart';
import '../../features/warehouse/screens/pick_list_screen.dart';
import '../../features/warehouse/screens/pick_detail_screen.dart';

// ── Route path constants ─────────────────────────────────────────────────────
class AppRoutes {
  AppRoutes._();

  static const splash       = '/splash';
  static const login        = '/login';
  static const home         = '/home';

  // Sales Rep
  static const beatPlan          = '/beat-plan';
  static const newOrder          = '/orders/new';
  static const orderDetail       = '/orders/:id';
  static const orderList         = '/orders';
  static const retailerList      = '/retailers';
  static const retailerDetail    = '/retailers/:id';
  static const quickCollect      = '/home/collect';
  static const collections       = '/home/collections';
  static const recentCollections = '/home/collections/recent';

  // Driver
  static const tripList     = '/trips';
  static const tripDetail   = '/trips/:id';
  static const stopDetail   = '/trips/:tripId/stops/:stopId';

  // Warehouse
  static const pickList   = '/picks';
  static const pickDetail = '/picks/:id';

  // Common
  static const notifications = '/notifications';
  static const settings      = '/settings';
  static const syncCenter    = '/sync';
}

/// The root GoRouter — guards unauthenticated access and handles deep links.
final appRouterProvider = Provider<GoRouter>((ref) {
  final storage = ref.watch(secureStorageProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final isLoggedIn = await storage.isLoggedIn();
      final isGoingToLogin  = state.matchedLocation == AppRoutes.login;
      final isGoingToSplash = state.matchedLocation == AppRoutes.splash;

      // Allow the splash screen through — it handles its own redirect after init
      if (isGoingToSplash) return null;

      if (!isLoggedIn && !isGoingToLogin) return AppRoutes.login;
      if (isLoggedIn && isGoingToLogin)   return AppRoutes.home;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (ctx, state) => const _SplashPlaceholder(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (ctx, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (ctx, state) => const HomeShell(),
        routes: [
          GoRoute(
            path: 'retailers',
            builder: (ctx, state) => const RetailerListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (ctx, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                  return RetailerProfileScreen(retailerId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'orders',
            builder: (ctx, state) => const OrderListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (ctx, state) => const SelectRetailerScreen(),
                routes: [
                  GoRoute(
                    path: 'products/:retailerId',
                    builder: (ctx, state) {
                      final id   = int.tryParse(state.pathParameters['retailerId'] ?? '') ?? 0;
                      final name = state.uri.queryParameters['name'] ?? '';
                      return ProductPickerScreen(customerId: id, customerName: name);
                    },
                  ),
                  GoRoute(
                    path: 'cart',
                    builder: (ctx, state) {
                      final extra      = state.extra as Map<String, dynamic>? ?? {};
                      final customerId = extra['customerId'] as int? ?? 0;
                      final customerName = extra['customerName'] as String? ?? '';
                      final branchId   = extra['branchId'] as int? ?? 1;
                      return CartReviewScreen(
                        customerId:   customerId,
                        customerName: customerName,
                        branchId:     branchId,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'credit-result',
                    builder: (ctx, state) {
                      final result = state.extra as CreditCheckResult;
                      return CreditCheckResultScreen(result: result);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'collect',
            builder: (ctx, state) {
              final extra               = state.extra as Map<String, dynamic>? ?? {};
              final customerId          = extra['customerId']           as int?;
              final customerName        = extra['customerName']         as String?;
              final amount              = (extra['amount'] as num?)?.toDouble();
              final collectionScheduleId = extra['collectionScheduleId'] as int?;
              return QuickCollectScreen(
                prefilledCustomerId:   customerId,
                prefilledCustomerName: customerName,
                prefilledAmount:       amount,
                collectionScheduleId:  collectionScheduleId,
              );
            },
          ),
          GoRoute(
            path: 'collections',
            builder: (ctx, state) => const CollectionScheduleScreen(),
            routes: [
              GoRoute(
                path: 'recent',
                builder: (ctx, state) => const RecentCollectionsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'trips',
            builder: (ctx, state) => const TripListScreen(),
            routes: [
              GoRoute(
                path: ':tripId',
                builder: (ctx, state) {
                  final tripId = int.tryParse(state.pathParameters['tripId'] ?? '') ?? 0;
                  return TripDetailScreen(tripId: tripId);
                },
                routes: [
                  GoRoute(
                    path: 'stops/:stopId',
                    builder: (ctx, state) {
                      final extra  = state.extra as Map<String, dynamic>? ?? {};
                      final stop   = extra['stop'] as TripStopItem? ??
                          const TripStopItem(
                              id: 0, sequence: 0, status: 'pending', salesOrderId: 0,
                              customerName: 'Customer');
                      final tripId = extra['tripId'] as int? ??
                          int.tryParse(state.pathParameters['tripId'] ?? '') ?? 0;
                      return StopDetailScreen(tripId: tripId, stop: stop);
                    },
                    routes: [
                      GoRoute(
                        path: 'partial',
                        builder: (ctx, state) {
                          final extra  = state.extra as Map<String, dynamic>? ?? {};
                          final stop   = extra['stop'] as TripStopItem? ??
                              const TripStopItem(
                                  id: 0, sequence: 0, status: 'pending', salesOrderId: 0,
                                  customerName: 'Customer');
                          final tripId = extra['tripId'] as int? ??
                              int.tryParse(state.pathParameters['tripId'] ?? '') ?? 0;
                          return PartialDeliveryScreen(tripId: tripId, stop: stop);
                        },
                      ),
                      GoRoute(
                        path: 'pod',
                        builder: (ctx, state) {
                          final extra   = state.extra as Map<String, dynamic>? ?? {};
                          final stop    = extra['stop'] as TripStopItem? ??
                              const TripStopItem(
                                  id: 0, sequence: 0, status: 'pending', salesOrderId: 0,
                                  customerName: 'Customer');
                          final tripId  = extra['tripId'] as int? ??
                              int.tryParse(state.pathParameters['tripId'] ?? '') ?? 0;
                          final outcome = extra['outcome'] as String? ?? 'delivered';
                          final lines   = (extra['deliveredLines'] as List<Map<String, dynamic>>?) ?? [];
                          final rejs    = (extra['rejections']     as List<Map<String, dynamic>>?) ?? [];
                          return PodCaptureScreen(
                            tripId:         tripId,
                            stop:           stop,
                            outcome:        outcome,
                            deliveredLines: lines,
                            rejections:     rejs,
                          );
                        },
                      ),
                      GoRoute(
                        path: 'returns',
                        builder: (ctx, state) {
                          final extra  = state.extra as Map<String, dynamic>? ?? {};
                          final stop   = extra['stop'] as TripStopItem? ??
                              const TripStopItem(
                                  id: 0, sequence: 0, status: 'pending', salesOrderId: 0,
                                  customerName: 'Customer');
                          final tripId = extra['tripId'] as int? ??
                              int.tryParse(state.pathParameters['tripId'] ?? '') ?? 0;
                          return ReturnsAtDeliveryScreen(tripId: tripId, stop: stop);
                        },
                      ),
                      GoRoute(
                        path: 'collect',
                        builder: (ctx, state) {
                          final extra  = state.extra as Map<String, dynamic>? ?? {};
                          final stop   = extra['stop'] as TripStopItem? ??
                              const TripStopItem(
                                  id: 0, sequence: 0, status: 'pending', salesOrderId: 0,
                                  customerName: 'Customer');
                          final tripId = extra['tripId'] as int? ??
                              int.tryParse(state.pathParameters['tripId'] ?? '') ?? 0;
                          return CashCollectionScreen(tripId: tripId, stop: stop);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'beat-plan',
            builder: (ctx, state) => const BeatPlanScreen(),
          ),
          // ── Warehouse: Pick List ──────────────────────────────────────────
          GoRoute(
            path: 'picks',
            builder: (ctx, state) => const PickListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (ctx, state) {
                  final orderId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                  return PickDetailScreen(orderId: orderId);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'beat-checkin',
            builder: (ctx, state) {
              final extra     = state.extra as Map<String, dynamic>? ?? {};
              final retailer  = extra['retailer'] as BeatRetailer? ?? const BeatRetailer(
                retailerId: 0, retailerName: '', sequence: null, lastVisitDate: null,
                visitId: null, visitStatus: null, phone: null, address: null);
              final onRefresh = extra['onRefresh'] as VoidCallback?;
              return CheckinScreen(retailer: retailer, onRefresh: onRefresh);
            },
          ),
          GoRoute(
            path: 'notifications',
            builder: (ctx, state) => const NotificationInboxScreen(),
          ),
          GoRoute(
            path: 'sync',
            builder: (ctx, state) => const SyncCenterScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (ctx, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

// ── Placeholder screens (replaced in Phase 1) ────────────────────────────────
import 'package:flutter/material.dart';

class _SplashPlaceholder extends StatefulWidget {
  const _SplashPlaceholder();
  @override
  State<_SplashPlaceholder> createState() => _SplashPlaceholderState();
}

class _SplashPlaceholderState extends State<_SplashPlaceholder> {
  @override
  void initState() {
    super.initState();
    // Navigate to login after a brief splash delay
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) context.go(AppRoutes.login);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Color(0xFF1B4332),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OL',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'OrdWave',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 48),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(label)),
        body: Center(
          child: Text(
            '$label — coming soon',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
