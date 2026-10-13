import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/models.dart';
import '../services/shop_api.dart';
import '../widgets/common.dart';
import 'catalog_screens.dart';
import 'main_shell.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _doSearch() {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    pushPage(context, ProductListScreen(title: 'Search', keyword: q));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Image.asset(
                'assets/images/brand_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                semanticLabel: 'BabyShopHub logo',
              ),
              const SizedBox(width: 8),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  children: [
                    TextSpan(
                        text: 'BabyShop',
                        style: TextStyle(color: AppColors.blue)),
                    TextSpan(
                        text: 'Hub', style: TextStyle(color: AppColors.pink)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _doSearch(),
            decoration: InputDecoration(
              hintText: 'Search clothes, plates, carriers, bottles...',
              prefixIcon: const Icon(Icons.search, color: AppColors.hint),
              filled: true,
              fillColor: AppColors.field,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        // Static promo banner — rendered immediately, no data dependency.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: _banner(context),
        ),
        Expanded(
          child: AsyncView<(List<Category>, List<Product>)>(
            load: () => (
              ShopApi.categories(),
              ShopApi.products(size: 8, sortBy: 'createdAt', direction: 'desc'),
            ).wait,
            builder: (context, data, reload) {
              final (categories, products) = data;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 16),
                  _categoryRow(context, categories),
                  SectionTitle('Popular Products',
                      action: 'See all',
                      onAction: () => pushPage(context,
                          const ProductListScreen(title: 'All Products'))),
                  if (products.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: EmptyView('No products yet.'))
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: products.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      itemBuilder: (context, i) => ProductCard(
                        product: products[i],
                        onTap: () => pushPage(
                            context, ProductDetailScreen(productId: products[i].id)),
                        onAdd: () => addToCartWithFeedback(context, products[i]),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _banner(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: double.infinity,
          height: 150,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/baby_b.jpg', fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.pinkTint.withValues(alpha: 0.98),
                      AppColors.pinkTint.withValues(alpha: 0.72),
                      AppColors.pinkTint.withValues(alpha: 0.10),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Happy Babies\nHappy Parents',
                          style: TextStyle(
                              color: AppColors.pink,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.15)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _categoryRow(BuildContext context, List<Category> categories) {
    final shown = categories.take(4).toList();
    Widget item(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                      color: AppColors.blueTint, shape: BoxShape.circle),
                  child: Icon(icon, color: AppColors.blue),
                ),
                const SizedBox(height: 6),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        for (final c in shown)
          item(
              categoryIcon(c.name),
              c.name,
              () => pushPage(context,
                  ProductListScreen(title: c.name, categoryId: c.id))),
        item(Icons.apps_rounded, 'More', () => MainShell.goTo(context, 1)),
      ],
    );
  }
}