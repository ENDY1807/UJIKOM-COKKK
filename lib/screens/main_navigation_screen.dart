import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'dashboard/dashboard_screen.dart';
import 'order/order_entry_screen.dart';
import 'cashier/cashier_screen.dart';
import 'reference/menu_management_screen.dart';
import 'reports/report_screen.dart';
import 'users/user_management_screen.dart';

class NavDestinationItem {
  final String label;
  final IconData icon;
  final Widget screen;
  const NavDestinationItem({
    required this.label,
    required this.icon,
    required this.screen,
  });
}

class MainNavigationScreen extends StatefulWidget {
  final DatabaseService db;
  final VoidCallback onLogout;

  const MainNavigationScreen({
    super.key,
    required this.db,
    required this.onLogout,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  List<NavDestinationItem> _getDestinationsForRole(UserRole role) {
    final list = <NavDestinationItem>[];

    // 1. Dashboard Utama: Seluruh role
    list.add(NavDestinationItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      screen: DashboardScreen(
        db: widget.db,
        onNavigateToTab: _navigateToTab,
      ),
    ));

    // 2. Order Entry: Admin, Waiter, Pelanggan
    if (role.canCreateOrder) {
      list.add(NavDestinationItem(
        label: role == UserRole.pelanggan ? 'Pesan Menu' : 'Entri Order',
        icon: Icons.restaurant_menu,
        screen: OrderEntryScreen(db: widget.db),
      ));
    }

    // 3. Transaksi Kasir: Admin, Kasir
    if (role.canProcessTransactions) {
      list.add(NavDestinationItem(
        label: 'Kasir & Tagihan',
        icon: Icons.point_of_sale,
        screen: CashierScreen(db: widget.db),
      ));
    }

    // 4. Entri Referensi: Admin only
    if (role.canManageReferences) {
      list.add(NavDestinationItem(
        label: 'Referensi Menu & Meja',
        icon: Icons.inventory_2_outlined,
        screen: MenuManagementScreen(db: widget.db),
      ));
    }

    // 5. Generate Laporan: Admin, Waiter, Kasir, Owner
    if (role.canViewReports) {
      list.add(NavDestinationItem(
        label: 'Laporan Penjualan',
        icon: Icons.analytics_outlined,
        screen: ReportScreen(db: widget.db),
      ));
    }

    // 6. Registrasi: Admin, Waiter, Kasir
    if (role.canRegisterUsers) {
      list.add(NavDestinationItem(
        label: role == UserRole.administrator ? 'Kelola User' : 'Registrasi Pelanggan',
        icon: Icons.people_outline,
        screen: UserManagementScreen(db: widget.db),
      ));
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.db.currentUser;
    final role = currentUser?.role ?? UserRole.pelanggan;
    final destinations = _getDestinationsForRole(role);

    // Guard index bounds
    if (_currentIndex >= destinations.length) {
      _currentIndex = 0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.orangeLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.orangeBorder),
                  ),
                  child: const Icon(Icons.restaurant, color: AppTheme.orangePrimary, size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Restoran Nusantara',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
              ],
            ),
            actions: [
              // Quick Role Switcher Dropdown
              PopupMenuButton<UserRole>(
                tooltip: 'Ganti Role Demo',
                onSelected: (newRole) {
                  widget.db.switchRole(newRole);
                  setState(() => _currentIndex = 0);
                },
                itemBuilder: (ctx) => UserRole.values.map((r) {
                  return PopupMenuItem(
                    value: r,
                    child: Row(
                      children: [
                        Icon(
                          r == role ? Icons.check_circle : Icons.circle_outlined,
                          size: 16,
                          color: r == role ? AppTheme.orangePrimary : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(r.label, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.orangeLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.orangeBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.badge_outlined, size: 16, color: AppTheme.orangePrimary),
                      const SizedBox(width: 6),
                      Text(
                        'Role: ${role.label}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.orangePrimary),
                    ],
                  ),
                ),
              ),
              if (isDesktop) ...[
                const SizedBox(width: 8),
                // User Profile Info on Desktop
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        currentUser?.namaUser ?? 'Pengguna',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 4),
              // Logout button
              IconButton(
                icon: const Icon(Icons.logout, color: AppTheme.statusRed, size: 20),
                tooltip: 'Keluar',
                onPressed: () {
                  widget.db.logout();
                  widget.onLogout();
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: isDesktop
              ? Row(
                  children: [
                    // Desktop Sidebar Navigation
                    Container(
                      width: 220,
                      decoration: const BoxDecoration(
                        color: AppTheme.white,
                        border: Border(right: BorderSide(color: AppTheme.borderSubtle)),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: destinations.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final item = destinations[index];
                                final isSelected = _currentIndex == index;

                                return InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => setState(() => _currentIndex = index),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.orangeLight : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? AppTheme.orangeBorder : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.icon,
                                          size: 20,
                                          color: isSelected ? AppTheme.orangePrimary : AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            item.label,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              color: isSelected ? AppTheme.orangePrimary : AppTheme.textDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.borderSubtle),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'UKK RPL 2026/2027',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Paket 1: Restoran POS',
                                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Desktop Main Content
                    Expanded(
                      child: destinations[_currentIndex].screen,
                    ),
                  ],
                )
              : destinations[_currentIndex].screen,
          // Mobile Bottom Bar Navigation
          bottomNavigationBar: !isDesktop && destinations.length > 1
              ? Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1)),
                  ),
                  child: NavigationBar(
                    backgroundColor: AppTheme.white,
                    indicatorColor: AppTheme.orangeLight,
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
                    destinations: destinations.map((item) {
                      return NavigationDestination(
                        icon: Icon(item.icon, color: AppTheme.textMuted),
                        selectedIcon: Icon(item.icon, color: AppTheme.orangePrimary),
                        label: item.label,
                      );
                    }).toList(),
                  ),
                )
              : null,
        );
      },
    );
  }
}
