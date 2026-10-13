import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../services/shop_api.dart';
import '../widgets/common.dart';
import 'product_detail_screen.dart';

/// Categories tab: grid of all categories.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: [
              const SizedBox(width: 48),
              const Expanded(
                child: Center(
                  child: Text('Categories',
                      style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: AppColors.navy),
                onPressed: () => pushPage(
                    context, const ProductListScreen(title: 'All Products')),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<List<Category>>(
            load: ShopApi.categories,
            builder: (context, categories, reload) {
              if (categories.isEmpty) {
                return const EmptyView('No categories yet.');
              }
              return GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: categories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, i) {
                  final c = categories[i];
                  return SoftCard(
                    onTap: () => pushPage(context,
                        ProductListScreen(title: c.name, categoryId: c.id)),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                              color: AppColors.blueTint,
                              shape: BoxShape.circle),
                          child: Icon(categoryIcon(c.name),
                              color: AppColors.blue),
                        ),
                        const SizedBox(height: 8),
                        Text(c.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Product list with search, brand filter and sorting.
/// Used for a category, a search, or "see all".
class ProductListScreen extends StatefulWidget {
  const ProductListScreen(
      {super.key, required this.title, this.categoryId, this.keyword});
  final String title;
  final int? categoryId;
  final String? keyword;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late final TextEditingController _search =
      TextEditingController(text: widget.keyword ?? '');
  List<Category> _categories = [];
  int? _selectedCategoryId;
  String _sortBy = 'productId';
  String _direction = 'asc';
  late Future<List<Product>> _future = _load();

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categoryId;
    ShopApi.categories().then((c) {
      if (mounted) setState(() => _categories = c);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Product>> _load() => ShopApi.products(
        keyword: _search.text,
        categoryId: _selectedCategoryId,
        sortBy: _sortBy,
        direction: _direction,
      );

  void _reload() => setState(() {
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    final categoryLabels = ['All Sections', ..._categories.map((c) => c.name)];
    final selectedCategory = _selectedCategoryId == null
        ? 0
        : 1 + _categories.indexWhere((c) => c.id == _selectedCategoryId);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          PopupMenuButton<(String, String)>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (v) {
              _sortBy = v.$1;
              _direction = v.$2;
              _reload();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: ('productId', 'asc'), child: Text('Default')),
              PopupMenuItem(value: ('name', 'asc'), child: Text('Name A-Z')),
              PopupMenuItem(
                  value: ('price', 'asc'), child: Text('Price: low to high')),
              PopupMenuItem(
                  value: ('price', 'desc'), child: Text('Price: high to low')),
              PopupMenuItem(
                  value: ('createdAt', 'desc'), child: Text('Newest')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _reload(),
              decoration: InputDecoration(
                hintText: 'Search clothes, plates, carriers, bottles...',
                prefixIcon: const Icon(Icons.search, color: AppColors.hint),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _search.clear();
                          _reload();
                        },
                      ),
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
          if (widget.categoryId == null && _categories.isNotEmpty)
            ChipRow(
              labels: categoryLabels,
              selected: selectedCategory < 0 ? 0 : selectedCategory,
              onSelected: (i) {
                _selectedCategoryId = i == 0 ? null : _categories[i - 1].id;
                _reload();
              },
            ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.blue));
                }
                if (snap.hasError) {
                  return ErrorView(snap.error.toString(), onRetry: _reload);
                }
                final products = snap.data!;
                if (products.isEmpty) {
                  return const EmptyView('No products found.',
                      icon: Icons.search_off);
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _row(context, products[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Product p) => SoftCard(
        onTap: () => pushPage(context, ProductDetailScreen(productId: p.id)),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ProductImage(p.imageUrl, size: 84),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  if (p.categoryName.isNotEmpty)
                    Text(p.categoryName,
                        style: const TextStyle(
                            color: AppColors.slate, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(p.inStock ? naira(p.price) : 'Out of stock',
                      style: TextStyle(
                          color: p.inStock ? AppColors.navy : AppColors.hint,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ],
              ),
            ),
            Material(
              color: p.inStock ? AppColors.blue : AppColors.field,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: p.inStock ? () => addToCartWithFeedback(context, p) : null,
                child: const Padding(
                  padding: EdgeInsets.all(9),
                  child: Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      );
}