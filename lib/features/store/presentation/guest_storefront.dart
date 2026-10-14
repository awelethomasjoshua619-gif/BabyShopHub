import 'package:flutter/material.dart';

import '../../../core/sequential.dart';
import '../../../core/api_config.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/models.dart';
import '../../../services/shop_api.dart';
import 'category_tab.dart';

class _StoreCategory {
  const _StoreCategory(this.name, this.icon, this.color);

  final String name;
  final IconData icon;
  final Color color;
}

/// Presentation wrapper around a real [Product] so the card stays unchanged.
class _StoreProduct {
  const _StoreProduct({
    required this.name,
    required this.category,
    required this.price,
    required this.image,
    required this.color,
  });

  factory _StoreProduct.from(Product p) => _StoreProduct(
        name: p.name,
        category: p.categoryName,
        price: naira(p.price),
        image: p.imageUrl,
        color: const Color(0xFFE7F1F8),
      );

  final String name;
  final String category;
  final String price;
  final String? image;
  final Color color;
}

class GuestStorefront extends StatefulWidget {
  const GuestStorefront({
    required this.onBackToGateway,
    required this.onRequireAccount,
    super.key,
  });

  final VoidCallback onBackToGateway;
  final ValueChanged<bool> onRequireAccount;

  @override
  State<GuestStorefront> createState() => _GuestStorefrontState();
}

class _GuestStorefrontState extends State<GuestStorefront> {
  // Live data from the backend, so guests never see placeholder products.
  List<_StoreCategory> _categories = const [];
  List<_StoreProduct> _products = const [];
  bool _loading = true;
  String? _error;

  final _searchController = TextEditingController();
  String? _selectedCategory;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await loadInOrder2(
        () => ShopApi.products(size: 50),
        () => ShopApi.categories(),
      );
      if (!mounted) return;
      final (products, categories) = result;
      setState(() {
        _products = products.map(_StoreProduct.from).toList();
        _categories = categories
            .take(5)
            .map((c) => _StoreCategory(
                  c.name,
                  Icons.category_outlined,
                  const Color(0xFFE6DFFF),
                ))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _requireAccount(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final media = MediaQuery.sizeOf(dialogContext);
        final compact = media.width < 380 || media.height < 600;
        final horizontalInset = switch (media.width) {
          < 360 => 16.0,
          < 600 => 22.0,
          _ => 32.0,
        };
        final contentPadding = compact ? 18.0 : 24.0;

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: horizontalInset,
            vertical: 24,
          ),
          backgroundColor: const Color(0xFFF9E7E8),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 24 : 30),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: media.height * 0.82,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: contentPadding,
                vertical: compact ? 18 : 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: const Color(0xFF218CF2),
                    size: compact ? 28 : 32,
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  Text(
                    'Join BabyShopHub',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF352E30),
                      fontSize: compact ? 21 : 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 9),
                  Text(
                    '$message Sign up or log in to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF554B4D),
                      fontSize: compact ? 13 : 14,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: compact ? 13 : 15),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        widget.onRequireAccount(true);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF934B58),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        widget.onRequireAccount(false);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF934B58),
                        side: const BorderSide(color: Color(0xFF9F8589)),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Login'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF934B58),
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: const Text('Keep browsing'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
      _selectedTab = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final products = _products.where((product) {
      final matchesCategory =
          _selectedCategory == null || product.category == _selectedCategory;
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFCFA),
      body: SafeArea(
        bottom: false,
        child: _selectedTab == 1
            ? CategoryTab(onCategorySelected: _selectCategory)
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 14, 0),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/brand_logo.png',
                            width: 31,
                            height: 31,
                            fit: BoxFit.contain,
                            semanticLabel: 'BabyShopHub logo',
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text.rich(
                              const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'BabyShop',
                                    style: TextStyle(color: Color(0xFF5683B3)),
                                  ),
                                  TextSpan(
                                    text: 'Hub',
                                    style: TextStyle(color: Color(0xFFE88791)),
                                  ),
                                ],
                              ),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Notifications',
                            onPressed: () => _requireAccount(
                              'Sign up to receive shopping updates.',
                            ),
                            icon: const Icon(Icons.notifications_none_rounded),
                          ),
                          IconButton(
                            tooltip: 'Back to welcome screen',
                            onPressed: widget.onBackToGateway,
                            icon: const Icon(Icons.logout_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 5, 14, 10),
                    sliver: SliverToBoxAdapter(
                      child: SizedBox(
                        height: 43,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search clothes, plates, carriers, bottles...',
                            hintStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF0F3F8),
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 13),
                    sliver: SliverToBoxAdapter(
                      child: _PromotionBanner(
                        onPressed: () => _selectCategory('Baby Food'),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 1, 14, 5),
                    sliver: SliverToBoxAdapter(
                      child: SizedBox(
                        height: 75,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final category in _categories)
                              _CategoryShortcut(
                                category: category,
                                selected: _selectedCategory == category.name,
                                onTap: () => _selectCategory(category.name),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 5, 12, 4),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Popular Products',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _selectedCategory = null;
                              _selectedTab = 1;
                            }),
                            child: const Text('See All'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_loading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF218CF2)),
                        ),
                      ),
                    )
                  else if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.ink)),
                            const SizedBox(height: 12),
                            TextButton(
                                onPressed: _load,
                                child: const Text('Try again')),
                          ],
                        ),
                      ),
                    )
                  else if (products.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(child: Text('No products found.')),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                      sliver: SliverGrid.builder(
                        itemCount: products.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.91,
                            ),
                        itemBuilder: (context, index) => _ProductCard(
                          product: products[index],
                          onOpen: () => _requireAccount(
                            'Create an account to view product details.',
                          ),
                          onAdd: () => _requireAccount(
                            'Sign up to add products to your cart.',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        selectedItemColor: const Color(0xFFE88791),
        unselectedItemColor: const Color(0xFF777777),
        onTap: (index) {
          if (index == 2 || index == 3 || index == 4) {
            final message = switch (index) {
              2 => 'Sign up to use your cart.',
              3 => 'Sign up to view your orders.',
              _ => 'Sign up to manage your profile.',
            };
            _requireAccount(message);
            return;
          }
          setState(() => _selectedTab = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _PromotionBanner extends StatelessWidget {
  const _PromotionBanner({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: SizedBox(
        height: 116,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/baby_b.jpg', fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFB6C2).withValues(alpha: 0.98),
                    const Color(0xFFFFB6C2).withValues(alpha: 0.70),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.48, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 9),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 142,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Happy Babies\nHappy Parents',
                        style: TextStyle(
                          color: Color(0xFFCB4663),
                          height: 1.05,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryShortcut extends StatelessWidget {
  const _CategoryShortcut({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _StoreCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                color: category.color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: const Color(0xFF6CAFE3), width: 2)
                    : null,
              ),
              child: Icon(
                category.icon,
                size: 19,
                color: const Color(0xFF5683A9),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onOpen,
    required this.onAdd,
  });

  final _StoreProduct product;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFF1EAE6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      child: ColoredBox(
                        color: product.color,
                        child: product.image == null || product.image!.isEmpty
                            ? const Center(
                                child: Icon(Icons.child_care,
                                    size: 34, color: Color(0xFF5683A9)))
                            : Image.network(
                                resolveImageUrl(product.image!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Center(
                                    child: Icon(Icons.child_care,
                                        size: 34, color: Color(0xFF5683A9))),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: onAdd,
                        customBorder: const CircleBorder(),
                        child: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.add_rounded,
                            color: Color(0xFF2F9BFF),
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.price,
                      style: const TextStyle(
                        color: Color(0xFF25517D),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
