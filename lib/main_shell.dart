import 'package:flutter/material.dart';

import 'features/cart/presentation/pages/cart_screen.dart';
import 'features/home/presentation/pages/home_screen.dart';
import 'features/offers/presentation/pages/offers_screen.dart';
import 'features/profile/presentation/pages/profile_screen.dart';
import 'l10n/app_strings.dart';
import 'shared/models/cart_item.dart';
import 'shared/services/cart_service.dart';

/// الهيكل الرئيسي للتطبيق مع شريط التنقل السفلي
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    OffersScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: AppStrings.home,
          ),
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer),
            label: AppStrings.offers,
          ),
          NavigationDestination(
            icon: _CartIcon(outlined: true),
            selectedIcon: _CartIcon(outlined: false),
            label: AppStrings.cart,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: AppStrings.profile,
          ),
        ],
      ),
    );
  }
}

/// أيقونة السلة مع عدّاد عدد القطع — يتحدّث فوراً مع أي إضافة/إزالة
/// (CartService.itemsStream)، ولا يظهر إطلاقاً إن كانت السلة فارغة
class _CartIcon extends StatelessWidget {
  const _CartIcon({required this.outlined});

  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CartItem>>(
      stream: CartService.instance.itemsStream,
      initialData: CartService.instance.items,
      builder: (context, snapshot) {
        final count = CartService.instance.totalItems;
        final icon = Icon(
          outlined ? Icons.shopping_cart_outlined : Icons.shopping_cart,
        );
        if (count <= 0) return icon;
        return Badge(
          label: Text(count > 99 ? '99+' : '$count'),
          child: icon,
        );
      },
    );
  }
}
