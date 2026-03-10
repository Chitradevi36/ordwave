import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/services/app_version_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/connectivity_banner.dart';
import '../../auth/screens/login_screen.dart' show LoginScreen;
import '../../home/screens/home_screen.dart' show SalesRepHome, DriverHome, GenericHome, UserProfile;
import '../../settings/screens/settings_screen.dart' show SettingsScreen;
import '../../retailers/screens/retailer_list_screen.dart' show RetailerListScreen;
import '../../orders/screens/select_retailer_screen.dart' show SelectRetailerScreen;
import '../../orders/screens/order_list_screen.dart' show OrderListScreen;
import '../../delivery/screens/trip_list_screen.dart' show TripListScreen;
import '../../beats/screens/beat_plan_screen.dart' show BeatPlanScreen;
import '../../orders/services/sync_engine.dart' show syncEngineProvider;

// ── Bottom nav index provider ─────────────────────────────────────────────────
final navIndexProvider = StateProvider<int>((_) => 0);

// ── Role-based shell ──────────────────────────────────────────────────────────
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  String? _role;
  bool    _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _checkAppVersion();
  }

  Future<void> _checkAppVersion() async {
    // Small delay so the first frame renders before showing any dialog
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final result = await ref.read(appVersionServiceProvider).checkVersion();
    if (mounted) handleVersionCheckResult(context, result);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Watch connectivity and auto-sync when back online
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) _wasOffline = true;
  }

  Future<void> _loadRole() async {
    final storage = ref.read(secureStorageProvider);
    final userJson = await storage.getUserJson();
    if (userJson == null || !mounted) return;
    try {
      final user = UserProfile.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      setState(() { _role = user.role; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final navIndex = ref.watch(navIndexProvider);

    // When connectivity is restored after being offline, trigger sync
    ref.listen<bool>(isOnlineProvider, (prev, next) {
      if (_wasOffline && next) {
        _wasOffline = false;
        ref.read(syncEngineProvider).processQueue();
      }
      if (!next) _wasOffline = true;
    });

    if (_role == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_role == 'sales_rep') {
      return _SalesRepShell(navIndex: navIndex);
    } else if (_role == 'driver') {
      return _DriverShell(navIndex: navIndex);
    } else {
      return const GenericHome();
    }
  }
}

// ── Sales Rep Shell ────────────────────────────────────────────────────────────
class _SalesRepShell extends ConsumerWidget {
  const _SalesRepShell({required this.navIndex});
  final int navIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = const [
      SalesRepHome(),
      BeatPlanScreen(),
      RetailerListScreen(),
      SelectRetailerScreen(),
      OrderListScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          const ConnectivityBanner(),
          Expanded(child: IndexedStack(index: navIndex, children: pages)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (i) => ref.read(navIndexProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label:        'Home',
          ),
          NavigationDestination(
            icon:         Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label:        'Beat',
          ),
          NavigationDestination(
            icon:         Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store),
            label:        'Retailers',
          ),
          NavigationDestination(
            icon:         Icon(Icons.add_shopping_cart_outlined),
            selectedIcon: Icon(Icons.add_shopping_cart),
            label:        'New Order',
          ),
          NavigationDestination(
            icon:         Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label:        'Orders',
          ),
          NavigationDestination(
            icon:         Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label:        'More',
          ),
        ],
      ),
    );
  }
}

// ── Driver Shell ───────────────────────────────────────────────────────────────
class _DriverShell extends ConsumerWidget {
  const _DriverShell({required this.navIndex});
  final int navIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = const [
      DriverHome(),
      TripListScreen(),
      _PlaceholderScreen(label: 'Collect',  icon: Icons.payments_outlined),
      SettingsScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          const ConnectivityBanner(),
          Expanded(child: IndexedStack(index: navIndex, children: pages)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (i) => ref.read(navIndexProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label:        'Home',
          ),
          NavigationDestination(
            icon:         Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label:        'My Trip',
          ),
          NavigationDestination(
            icon:         Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label:        'Collect',
          ),
          NavigationDestination(
            icon:         Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label:        'More',
          ),
        ],
      ),
    );
  }
}

// ── Placeholder coming-soon screen ─────────────────────────────────────────────
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label, required this.icon});
  final String   label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(label)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: OlColors.textDisabled),
              const SizedBox(height: 16),
              Text(
                '$label coming soon',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: OlColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
}
