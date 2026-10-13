import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../services/shop_api.dart';
import '../widgets/common.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final int productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;
  bool _adding = false;
  int _image = 0;
  late Future<(Product, List<Review>)> _future = _load();

  Future<(Product, List<Review>)> _load() =>
      (ShopApi.product(widget.productId), ShopApi.reviews(widget.productId))
          .wait;

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _add(Product p) async {
    setState(() => _adding = true);
    await addToCartWithFeedback(context, p, _qty);
    if (mounted) setState(() => _adding = false);
  }

  Future<void> _writeReview() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ReviewSheet(productId: widget.productId),
    );
    if (done == true) {
      _reload();
      if (mounted) showMessage(context, 'Thanks for your review!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: FutureBuilder<(Product, List<Review>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.blue));
          }
          if (snap.hasError) {
            return ErrorView(snap.error.toString(), onRetry: _reload);
          }
          final (p, reviews) = snap.data!;
          final avg = reviews.isEmpty
              ? 0.0
              : reviews.fold<int>(0, (s, r) => s + r.rating) / reviews.length;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    _gallery(p),
                    const SizedBox(height: 16),
                    Text(p.name,
                        style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(p.categoryName,
                        style: const TextStyle(
                            color: AppColors.slate, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        StarRating(avg),
                        const SizedBox(width: 6),
                        Text(
                            reviews.isEmpty
                                ? 'No reviews yet'
                                : '${avg.toStringAsFixed(1)} (${reviews.length} reviews)',
                            style: const TextStyle(
                                color: AppColors.slate, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(naira(p.price),
                            style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 24,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        p.inStock
                            ? '${p.stockQty} in stock'
                            : 'Currently out of stock',
                        style: TextStyle(
                            color: p.inStock
                                ? AppColors.success
                                : AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    if ((p.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(p.description!,
                          style: const TextStyle(
                              color: AppColors.slate, height: 1.45)),
                    ],
                    if (p.inStock) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Text('Quantity',
                              style: TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700)),
                          const Spacer(),
                          QuantityStepper(
                              value: _qty,
                              max: p.stockQty,
                              onChanged: (v) => setState(() => _qty = v)),
                        ],
                      ),
                    ],
                    SectionTitle('Customer Reviews',
                        action: 'Write a review', onAction: _writeReview),
                    if (reviews.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Be the first to review this product.',
                              style: TextStyle(color: AppColors.slate)))
                    else
                      for (final r in reviews) _reviewTile(r),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                color: Colors.white,
                child: SafeArea(
                  top: false,
                  child: PrimaryButton(
                    label: p.inStock ? 'Add to Cart' : 'Out of stock',
                    pink: true,
                    icon: Icons.shopping_cart_outlined,
                    loading: _adding,
                    onPressed: p.inStock ? () => _add(p) : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _gallery(Product p) {
    if (p.imageUrls.length <= 1) {
      return SizedBox(
          height: 240,
          child: SizedBox(width: double.infinity, child: ProductImage(p.imageUrl, iconSize: 80)));
    }
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            itemCount: p.imageUrls.length,
            onPageChanged: (i) => setState(() => _image = i),
            itemBuilder: (_, i) => ProductImage(p.imageUrls[i]),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < p.imageUrls.length; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _image ? AppColors.blue : AppColors.border),
              ),
          ],
        ),
      ],
    );
  }

  Widget _reviewTile(Review r) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.blueTint,
                    child: Text(
                        r.reviewer.isEmpty ? '?' : r.reviewer[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.blue, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(r.reviewer,
                          style: const TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w600))),
                  StarRating(r.rating.toDouble(), size: 15),
                ],
              ),
              if ((r.comment ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(r.comment!, style: const TextStyle(color: AppColors.ink)),
              ],
              const SizedBox(height: 6),
              Text(formatDate(r.createdAt),
                  style: const TextStyle(color: AppColors.hint, fontSize: 11)),
            ],
          ),
        ),
      );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.productId});
  final int productId;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 5;
  final _comment = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await ShopApi.addReview(widget.productId, _rating, _comment.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Write a Review',
              style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                      i <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 34,
                      color: AppColors.warning),
                ),
            ],
          ),
          TextField(
            controller: _comment,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Share your experience'),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
              label: 'Submit Review', loading: _saving, onPressed: _submit),
        ],
      ),
    );
  }
}